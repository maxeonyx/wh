using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows;

namespace wh;

public partial class MainWindow : Window
{
    private readonly Args _args;
    private readonly ILog _log;

    public MainWindow(Args args, ILog log)
    {
        _args = args;
        _log = log;
        InitializeComponent();
        Loaded += async (_, __) => await StartTranscriptionAsync();
    }

    private async Task StartTranscriptionAsync()
    {
        // Determine WAV path
        var wav = _args.E2eWavPath;
        if (string.IsNullOrWhiteSpace(wav))
        {
            // Default to sample path in repo when present (developer convenience)
            var repoWav = Path.Combine(AppContext.BaseDirectory, "assets", "audio", "hello.wav");
            if (File.Exists(repoWav)) wav = repoWav;
        }

        if (string.IsNullOrWhiteSpace(wav) || !File.Exists(wav))
        {
            TranscriptText.Text = "No WAV provided (--e2e-wav) and default missing.";
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

