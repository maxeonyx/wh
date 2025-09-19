using System;
using System.IO;
using System.Windows;
using System.Runtime.InteropServices;

namespace wh;

public partial class App : System.Windows.Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        TryAttachConsole();
        ILog logger = new ConsoleLogger();

        logger.Info("app.start",
            ("args", string.Join(" ", e.Args)),
            ("process", Environment.ProcessPath ?? string.Empty),
            ("base_dir", AppContext.BaseDirectory),
            ("runtime_dir", Environment.GetEnvironmentVariable("WH_RUNTIME_DIR") ?? string.Empty),
            ("bundle_extract", Environment.GetEnvironmentVariable("DOTNET_BUNDLE_EXTRACT_BASE_DIR") ?? string.Empty)
        );

        // Ensure native DLL resolver is configured before any P/Invoke
        NativeBootstrap.Configure();

        // Optional headless modes for CI/tooling (no window, no focus changes)
        var headless = Environment.GetEnvironmentVariable("WH_HEADLESS");
        if (!string.IsNullOrWhiteSpace(headless))
        {
            try
            {
                if (string.Equals(headless, "seed", StringComparison.OrdinalIgnoreCase))
                {
                    ModelManager.EnsureModelAsync(logger).GetAwaiter().GetResult();
                    Shutdown(0);
                    return;
                }
                if (string.Equals(headless, "transcribe", StringComparison.OrdinalIgnoreCase))
                {
                    // Find WAV via shared helper
                    var wav = WavFinder.FindHelloWavOrThrow(AppContext.BaseDirectory);

                    // Do not download/verify here; tests ensure the model is cached.
                    var model = ModelManager.GetModelPath();
                    Native.Init(model);
                    var text = Native.TranscribeWav(wav);
                    var outPath = Environment.GetEnvironmentVariable("WH_HEADLESS_OUT");
                    if (!string.IsNullOrWhiteSpace(outPath))
                    {
                        System.IO.File.WriteAllText(outPath!, text ?? string.Empty);
                    }
                    else
                    {
                        // Best-effort console; may be ignored for WinExe. Kept for dev convenience.
                        try { Console.WriteLine(text); } catch { }
                    }
                    Shutdown(0);
                    return;
                }
            }
            catch (Exception ex)
            {
                logger.Error("headless.error", ("error", ex.Message));
                Shutdown(2);
                return;
            }
        }

        // Capture UI-thread faults early with actionable logs
        this.DispatcherUnhandledException += (s, exArgs) =>
        {
            try { logger.Error("ui.dispatcher_unhandled", ("error", exArgs.Exception.Message)); }
            catch { }
            // Fail fast per precision mindset
            try { Current.Shutdown(3); } catch { }
        };

        var win = new MainWindow(logger);
        win.Show();
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AttachConsole(int dwProcessId);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AllocConsole();
    private const int ATTACH_PARENT_PROCESS = -1;

    private static void TryAttachConsole()
    {
        try { AttachConsole(ATTACH_PARENT_PROCESS); } catch { }
    }

    private static bool HasConsole()
    {
        try { Console.CursorVisible = Console.CursorVisible; return true; } catch { return false; }
    }
}


