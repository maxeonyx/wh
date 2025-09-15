using System;
using System.IO;
using System.Windows;

namespace wh;

public partial class App : System.Windows.Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var args = Args.Parse(e.Args);
        var logsDir = ModelManager.GetLogsRoot();
        var logPath = Path.Combine(logsDir, "wh.log");
        var logger = new FileLogger(logPath);
        logger.Info("app.start",
            ("args", string.Join(" ", e.Args)),
            ("process", Environment.ProcessPath ?? string.Empty),
            ("base_dir", AppContext.BaseDirectory),
            ("runtime_dir", Environment.GetEnvironmentVariable("WH_RUNTIME_DIR") ?? string.Empty),
            ("bundle_extract", Environment.GetEnvironmentVariable("DOTNET_BUNDLE_EXTRACT_BASE_DIR") ?? string.Empty)
        );

        var win = new MainWindow(args, logger);
        win.Show();
    }
}

