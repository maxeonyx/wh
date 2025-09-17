using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows;

namespace wh;

public partial class MainWindow : Window
{
    private readonly ILog _log;

    public MainWindow(ILog log)
    {
        _log = log;
        InitializeComponent();
        Loaded += async (_, __) => await StartTranscriptionAsync();
    }

    private async Task StartTranscriptionAsync()
    {
        // Determine WAV path: look for assets/audio/hello.wav near app; walk up a few directories
        string? wav = null;
        var dir = AppContext.BaseDirectory;
        for (int i = 0; i < 4 && string.IsNullOrEmpty(wav); i++)
        {
            var candidate = Path.GetFullPath(Path.Combine(dir, "assets", "audio", "hello.wav"));
            if (File.Exists(candidate)) { wav = candidate; break; }
            var parent = Directory.GetParent(dir)?.FullName;
            if (string.IsNullOrEmpty(parent)) break;
            dir = parent;
        }

        if (string.IsNullOrWhiteSpace(wav) || !File.Exists(wav))
        {
            TranscriptText.Text = "No WAV found at assets/audio/hello.wav.";
            _log.Warn("transcribe.no_wav");
            return;
        }

        try
        {
            _log.Info("startup", ("wav", wav));
            await ModelManager.EnsureModelAsync(_log);
            var model = ModelManager.GetModelPath();
            _log.Info("native.init", ("model", model));
            Native.Init(model);
            _log.Info("transcribe.start", ("path", wav));
            var text = await Task.Run(() => Native.TranscribeWav(wav));
            _log.Info("transcribe.done", ("chars", text.Length));
            TranscriptText.Text = text;
        }
        catch (Exception ex)
        {
            _log.Error("transcribe.error", ("error", ex.Message));
            TranscriptText.Text = "Error: " + ex.Message;
        }
    }
}
