#include "whisper.h"
#include <cstring>
#include <mutex>

static struct whisper_context* g_ctx = nullptr;
static std::mutex g_mutex;

extern "C" {

#ifdef _WIN32
#define DLL_EXPORT __declspec(dllexport)
#else
#define DLL_EXPORT
#endif

DLL_EXPORT int wh_init(const char* model_path) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_ctx) return 0;
    g_ctx = whisper_init_from_file(model_path);
    return g_ctx ? 0 : -1;
}

DLL_EXPORT const char* wh_transcribe(const float* samples, int count) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_ctx) return nullptr;
    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    if (whisper_full(g_ctx, params, samples, count) != 0) return nullptr;
    const char* text = whisper_full_get_segment_text(g_ctx, 0);
    return text ? strdup(text) : nullptr;
}

DLL_EXPORT void wh_free_result(const char* result) {
    if (result) free((void*)result);
}

DLL_EXPORT void wh_shutdown() {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_ctx) {
        whisper_free(g_ctx);
        g_ctx = nullptr;
    }
}

} // extern "C"
