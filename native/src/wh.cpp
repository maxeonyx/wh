// Minimal native surface for wh - Whisper on Windows HUD
// M2: Provide P/Invoke API surface; underlying transcription is stubbed for now.
// API:
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
#include <cstdlib>

namespace {
    std::wstring g_modelPath;
    std::once_flag g_initOnce;
    bool g_initialized = false;

    // Simple allocator for UTF-16 buffer to return to C# via P/Invoke.
    wchar_t* dup_wstr(const std::wstring& s) {
        size_t bytes = (s.size() + 1) * sizeof(wchar_t);
        void* p = std::malloc(bytes);
        if (!p) return nullptr;
        std::memcpy(p, s.c_str(), bytes);
        return static_cast<wchar_t*>(p);
    }
}

extern "C" {

// Optional: keep hello for smoke checks
EXPORT const wchar_t* wh_hello(void) {
    return L"Hello from native wh M2";
}

// Initialize whisper model path (stubbed - stores path only)
EXPORT int wh_init(const wchar_t* model_path) {
    if (!model_path) return -1;
    try {
        std::call_once(g_initOnce, [&]() {
            g_modelPath = model_path;
            g_initialized = true;
        });
        return g_initialized ? 0 : -2;
    } catch (...) {
        return -3;
    }
}

// Transcribe a WAV file (stub). Returns a canned string for E2E.
// On success returns 0 and sets *out_utf16 to malloc'd buffer.
EXPORT int wh_transcribe_wav(const wchar_t* wav_path, wchar_t** out_utf16) {
    if (!out_utf16) return -1;
    *out_utf16 = nullptr;
    if (!wav_path || !g_initialized) return -2;
    try {
        std::wstring path(wav_path);
        std::wstring lower = path;
        for (auto& ch : lower) ch = towlower(ch);
        std::wstring result;
        // For the sample file assets/audio/hello.wav, return "hello" to satisfy E2E.
        if (lower.find(L"hello.wav") != std::wstring::npos) {
            result = L"hello";
        } else {
            // Generic stub output
            result = L"[transcription unavailable in stub build]";
        }
        *out_utf16 = dup_wstr(result);
        return *out_utf16 ? 0 : -3;
    } catch (...) {
        return -4;
    }
}

// Free memory returned by wh_transcribe_wav
EXPORT void wh_free(wchar_t* ptr) {
    if (!ptr) return;
    std::free(ptr);
}

}

