using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Input;

namespace wh;

public partial class MainWindow : Window
{
    private readonly ILog _log;
    private readonly ITextInjector _injector;

    public MainWindow(ILog log)
    {
        _log = log;
        _injector = SelectInjector();
        InitializeComponent();
        SourceInitialized += (_, __) => ApplyNoActivateStyle();
        Loaded += async (_, __) =>
        {
            CenterOnCursorDisplay();
            await StartTranscriptionAsync();
        };
    }

    private static ITextInjector SelectInjector()
    {
        var overrideName = Environment.GetEnvironmentVariable("WH_INJECTOR");
        if (!string.IsNullOrWhiteSpace(overrideName))
        {
            if (string.Equals(overrideName, "clipboard", StringComparison.OrdinalIgnoreCase))
                return new ClipboardPasteInjector();
        }
        return new SendInputTextInjector();
    }

    private void Header_MouseDown(object? sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton == MouseButton.Left)
        {
            try { DragMove(); } catch { }
        }
    }

    private void Close_Click(object? sender, RoutedEventArgs e) => System.Windows.Application.Current.Shutdown(0);

    private void CenterOnCursorDisplay()
    {
        try
        {
            var p = System.Windows.Forms.Control.MousePosition;
            var screen = System.Windows.Forms.Screen.FromPoint(new System.Drawing.Point(p.X, p.Y));
            var work = screen.WorkingArea;
            var width = this.Width;
            var height = this.Height;
            this.Left = work.Left + (work.Width - width) / 2.0;
            this.Top = work.Top + (work.Height - height) / 2.0;
        }
        catch { }
    }

    private void ApplyNoActivateStyle()
    {
        try
        {
            var hwnd = new WindowInteropHelper(this).Handle;
            const int GWL_EXSTYLE = -20;
            const int WS_EX_NOACTIVATE = 0x08000000;

            IntPtr ex = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
            var newEx = new IntPtr(ex.ToInt64() | WS_EX_NOACTIVATE);
            SetWindowLongPtr(hwnd, GWL_EXSTYLE, newEx);
        }
        catch { /* best-effort: ShowActivated=False still prevents activation */ }
    }

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
    private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", EntryPoint = "SetWindowLong", SetLastError = true)]
    private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

    private static IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex)
        => IntPtr.Size == 8 ? GetWindowLongPtr64(hWnd, nIndex) : new IntPtr(GetWindowLong32(hWnd, nIndex));

    private static void SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong)
    {
        if (IntPtr.Size == 8)
            SetWindowLongPtr64(hWnd, nIndex, dwNewLong);
        else
            SetWindowLong32(hWnd, nIndex, dwNewLong.ToInt32());
    }

    private async Task StartTranscriptionAsync()
    {
        try
        {
            var wav = WavFinder.FindHelloWav(AppContext.BaseDirectory);
            if (string.IsNullOrWhiteSpace(wav) || !File.Exists(wav))
            {
                TranscriptText.Text = "No WAV found at assets/audio/hello.wav.";
                _log.Warn("transcribe.no_wav");
                return;
            }

            _log.Info("startup", ("wav", wav));
            await ModelManager.EnsureModelAsync(_log);
            var model = ModelManager.GetModelPath();
            _log.Info("native.init", ("model", model));
            Native.Init(model);
            _log.Info("transcribe.start", ("path", wav));
            var text = await Task.Run(() => Native.TranscribeWav(wav));
            _log.Info("transcribe.done", ("chars", text.Length));
            TranscriptText.Text = text;
            _log.Info("inject.start", ("chars", text.Length));
            _injector.Insert(text);
            _log.Info("inject.done", ("chars", text.Length));
            StatusText.Text = " Ready";
            // Close immediately after injection to signal completion to controller/test.
            System.Windows.Application.Current.Shutdown(0);
        }
        catch (Exception ex)
        {
            _log.Error("transcribe.error", ("error", ex.Message));
            TranscriptText.Text = "Error: " + ex.Message;
            throw;
        }
    }
}
