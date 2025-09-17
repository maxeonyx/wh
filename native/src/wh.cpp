// Native wrapper for whisper.cpp v1.5.4
// Exported API:
//   int wh_init(const wchar_t* model_path)
//   int wh_transcribe_wav(const wchar_t* wav_path, wchar_t** out_utf16)
//   void wh_free(wchar_t* ptr)

#ifdef _WIN32
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
#  define EXPORT __declspec(dllexport)
#else
#  define EXPORT
#endif

#include <cwchar>
#include <cstring>
#include <string>
#include <mutex>
#include <vector>
#include <thread>
#include <cstdlib>

// whisper.cpp headers (vendored under native/whisper.cpp)
#include "../whisper.cpp/whisper.h"

// Minimal WAV loader (dr_wav from whisper.cpp examples)
#define DR_WAV_IMPLEMENTATION
#include "../whisper.cpp/examples/dr_wav.h"

namespace {
    std::once_flag g_initOnce;
    whisper_context* g_ctx = nullptr;
    std::mutex g_mutex;

    wchar_t* dup_wstr(const std::wstring& s) {
        const size_t bytes = (s.size() + 1) * sizeof(wchar_t);
        void* p = std::malloc(bytes);
        if (!p) return nullptr;
        std::memcpy(p, s.c_str(), bytes);
        return static_cast<wchar_t*>(p);
    }

    std::string wide_to_utf8(const wchar_t* ws) {
        if (!ws) return std::string();
#ifdef _WIN32
        int len = WideCharToMultiByte(CP_UTF8, 0, ws, -1, nullptr, 0, nullptr, nullptr);
        if (len <= 0) return std::string();
        std::string out; out.resize(size_t(len - 1));
        WideCharToMultiByte(CP_UTF8, 0, ws, -1, out.data(), len, nullptr, nullptr);
        return out;
#else
        std::wstring w(ws);
        return std::string(w.begin(), w.end());
#endif
    }

    // Downmix to mono if needed
    std::vector<float> to_mono(const float* buf, uint32_t channels, uint64_t frames) {
        std::vector<float> mono;
        if (channels == 1) {
            mono.assign(buf, buf + frames);
            return mono;
        }
        mono.resize(frames);
        for (uint64_t i = 0; i < frames; ++i) {
            double sum = 0.0;
            for (uint32_t ch = 0; ch < channels; ++ch) {
                sum += buf[i*channels + ch];
            }
            mono[i] = (float)(sum / (double)channels);
        }
        return mono;
    }

    // Simple linear resampler to 16000 Hz
    std::vector<float> resample_16k(const std::vector<float>& in, uint32_t src_rate) {
        const uint32_t dst_rate = 16000;
        if (src_rate == dst_rate) return in;
        const double scale = (double)dst_rate / (double)src_rate;
        const size_t out_len = (size_t)((double)in.size() * scale);
        std::vector<float> out(out_len);
        for (size_t i = 0; i < out_len; ++i) {
            double x = (double)i / scale;
            size_t i0 = (size_t)x;
            size_t i1 = i0 + 1;
            double t = x - (double)i0;
            float s0 = i0 < in.size() ? in[i0] : 0.0f;
            float s1 = i1 < in.size() ? in[i1] : s0;
            out[i] = s0 + (float)((s1 - s0) * t);
        }
        return out;
    }

    // Load WAV file and produce 16 kHz mono PCM float
    int load_wav_16k_mono(const wchar_t* wav_path, std::vector<float>& audio_out) {
        const std::string path8 = wide_to_utf8(wav_path);
        drwav wav;
        if (!drwav_init_file(&wav, path8.c_str(), nullptr)) {
            return -10; // cannot open
        }
        std::vector<float> pcm; pcm.resize((size_t)wav.totalPCMFrameCount * wav.channels);
        uint64_t frames_read = drwav_read_pcm_frames_f32(&wav, wav.totalPCMFrameCount, pcm.data());
        uint32_t rate = wav.sampleRate;
        uint32_t channels = wav.channels;
        drwav_uninit(&wav);
        if (frames_read == 0) return -11; // empty
        // downmix
        auto mono = to_mono(pcm.data(), channels, frames_read);
        // resample
        audio_out = resample_16k(mono, rate);
        return 0;
    }
}

extern "C" {

// Initialize the whisper model and keep the context for reuse
EXPORT int wh_init(const wchar_t* model_path) {
    if (!model_path) return -1;
    int rc = 0;
    try {
        std::call_once(g_initOnce, [&]() {
            std::string mpath = wide_to_utf8(model_path);
            whisper_context_params cparams = whisper_context_default_params();
            // disable unnecessary backends on Windows by default
            cparams.use_gpu = false;
            g_ctx = whisper_init_from_file_with_params(mpath.c_str(), cparams);
        });
        if (!g_ctx) rc = -2;
    } catch (...) {
        rc = -3;
    }
    return rc;
}

// Transcribe a WAV file using whisper.cpp
// Returns 0 on success, allocates UTF-16 buffer via malloc for caller to free via wh_free
EXPORT int wh_transcribe_wav(const wchar_t* wav_path, wchar_t** out_utf16) {
    if (!out_utf16) return -1;
    *out_utf16 = nullptr;
    if (!wav_path || !g_ctx) return -2;

    std::vector<float> audio;
    int lrc = load_wav_16k_mono(wav_path, audio);
    if (lrc != 0) return lrc;

    int rc = 0;
    try {
        std::lock_guard<std::mutex> lock(g_mutex);
        whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        wparams.print_realtime   = false;
        wparams.print_progress   = false;
        wparams.print_timestamps = false;
        wparams.translate        = false;
        wparams.no_timestamps    = true;
        wparams.language         = "en";
        unsigned n_threads = std::max(1u, std::thread::hardware_concurrency());
        wparams.n_threads = (int)n_threads;

        if (whisper_full(g_ctx, wparams, audio.data(), (int)audio.size()) != 0) {
            return -20;
        }

        std::wstring out;
        const int n_segments = whisper_full_n_segments(g_ctx);
        for (int i = 0; i < n_segments; ++i) {
            const char* ctext = whisper_full_get_segment_text(g_ctx, i);
            if (!ctext) continue;
            // convert UTF-8 to UTF-16
#ifdef _WIN32
            int needed = MultiByteToWideChar(CP_UTF8, 0, ctext, -1, nullptr, 0);
            if (needed > 1) {
                std::wstring tmp; tmp.resize(needed - 1);
                MultiByteToWideChar(CP_UTF8, 0, ctext, -1, tmp.data(), needed);
                out += tmp;
            }
#else
            std::string tmp8(ctext);
            out.append(tmp8.begin(), tmp8.end());
#endif
        }
        // Trim whitespace
        auto is_space = [](wchar_t ch){ return ch == L' ' || ch == L'\t' || ch == L'\n' || ch == L'\r'; };
        size_t start = 0, end = out.size();
        while (start < end && is_space(out[start])) ++start;
        while (end > start && is_space(out[end-1])) --end;
        std::wstring trimmed = out.substr(start, end - start);

        *out_utf16 = dup_wstr(trimmed);
        if (!*out_utf16) rc = -21;
    } catch (...) {
        rc = -22;
    }
    return rc;
}

// Free memory returned by wh_transcribe_wav
EXPORT void wh_free(wchar_t* ptr) {
    if (ptr) std::free(ptr);
}

}
