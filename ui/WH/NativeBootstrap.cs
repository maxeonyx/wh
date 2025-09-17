using System;
using System.IO;
using System.Runtime.InteropServices;

namespace wh;

internal static class NativeBootstrap
{
    private static bool _configured;

    public static void Configure()
    {
        if (_configured) return;
        _configured = true;
        var rid = RuntimeInformation.RuntimeIdentifier;
        var baseDir = AppContext.BaseDirectory;
        var candidate = Path.Combine(baseDir, "runtimes", rid, "native", "wh.dll");
        var extractBase = Environment.GetEnvironmentVariable("DOTNET_BUNDLE_EXTRACT_BASE_DIR");
        if (!string.IsNullOrWhiteSpace(extractBase))
        {
            try
            {
                var appFolder = Path.Combine(extractBase!, "wh");
                if (Directory.Exists(appFolder))
                {
                    foreach (var dir in Directory.EnumerateDirectories(appFolder))
                    {
                        var path2 = Path.Combine(dir, "runtimes", rid, "native", "wh.dll");
                        if (File.Exists(path2)) { candidate = path2; break; }
                    }
                }
            }
            catch { }
        }
        NativeLibrary.SetDllImportResolver(typeof(Native).Assembly, (name, asm, path) =>
        {
            // Let the runtime try its default resolution (includes single-file extraction dirs)
            if (NativeLibrary.TryLoad(name, asm, path, out var handle))
                return handle;

            // Fallback: explicit path under runtimes/<rid>/native
            if ((string.Equals(name, "wh", StringComparison.OrdinalIgnoreCase) || string.Equals(name, "wh.dll", StringComparison.OrdinalIgnoreCase)))
            {
                if (File.Exists(candidate))
                {
                    return NativeLibrary.Load(candidate);
                }
            }
            return IntPtr.Zero;
        });
    }
}
