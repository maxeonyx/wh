#ifdef _WIN32
#  define EXPORT __declspec(dllexport)
#else
#  define EXPORT
#endif

#include <wchar.h>

// Simple native stub to prove native<->UI wiring in M1.
// Returns a static wide string literal.
EXPORT const wchar_t* wh_hello(void) {
    return L"Hello from native wh stub";
}

