using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace TextSink;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        TryAttachConsole();
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        var form = new Form
        {
            Text = "wh-tests TextSink",
            StartPosition = FormStartPosition.CenterScreen,
            Width = 600,
            Height = 300
        };

        var label = new Label
        {
            Text = "Focus the box below and wait for injection.",
            Dock = DockStyle.Top,
            Height = 24
        };

        var box = new TextBox
        {
            Name = "SinkTextBox",
            Multiline = true,
            AcceptsReturn = true,
            Dock = DockStyle.Fill,
            Font = new Font("Consolas", 11f)
        };

        form.Controls.Add(box);
        form.Controls.Add(label);
        var exe = Environment.GetEnvironmentVariable("WH_E2E_EXE");
        if (string.IsNullOrWhiteSpace(exe) || !System.IO.File.Exists(exe))
        {
            MessageBox.Show("WH_E2E_EXE not set or missing.", "TextSink", MessageBoxButtons.OK, MessageBoxIcon.Error);
            Environment.Exit(2);
            return;
        }

        var expected = Environment.GetEnvironmentVariable("WH_E2E_EXPECTED");
        if (string.IsNullOrEmpty(expected))
            expected = "hello this is the developer - the text injection didn't work, but this is a test to see whether the test would otherwise have worked";
        Console.WriteLine("[TextSink] Expected: " + expected);

        var timeoutEnv = Environment.GetEnvironmentVariable("WH_E2E_TIMEOUT");
        var capturePath = Environment.GetEnvironmentVariable("WH_E2E_CAPTURE");
        int timeoutSec = 10;
        if (!string.IsNullOrWhiteSpace(timeoutEnv)) int.TryParse(timeoutEnv, out timeoutSec);
        if (timeoutSec <= 0) timeoutSec = 10;

        Process? hud = null;
        form.Shown += (_, __) =>
        {
            // Take focus once
            try
            {
                NativeMethods.ShowWindow(form.Handle, 9); // SW_RESTORE
                NativeMethods.SetForegroundWindow(form.Handle);
                box.Focus();
                Console.WriteLine("[TextSink] Focus requested on text box.");
            }
            catch { }

            // Launch HUD
            hud = Process.Start(new ProcessStartInfo
            {
                FileName = exe!,
                UseShellExecute = false
            });

            // Poll for text until timeout
            var started = DateTime.UtcNow;
            var timer = new System.Windows.Forms.Timer { Interval = 250 };
            string last = string.Empty;
            timer.Tick += (_, ___) =>
            {
                var t = box.Text?.Trim() ?? string.Empty;
                if (!string.Equals(t, last, StringComparison.Ordinal))
                {
                    last = t;
                    Console.WriteLine("[TextSink] OBS: " + t);
                }
                if (hud != null && hud.HasExited)
                {
                    timer.Stop();
                    var finalText = t;
                    try {
                        if (!string.IsNullOrWhiteSpace(capturePath))
                        {
                            System.IO.File.WriteAllText(capturePath!, "OBS:" + finalText + Environment.NewLine + "EXP:" + expected);
                        }
                    } catch { }
                    int ok = string.Equals(finalText, expected, StringComparison.Ordinal) ? 0 : 1;
                    Console.WriteLine("[TextSink] Result: " + (ok == 0 ? "match" : "mismatch"));
                    try { if (hud != null && !hud.HasExited) hud.Kill(); } catch { }
                    Environment.Exit(ok);
                }
                if ((DateTime.UtcNow - started).TotalSeconds > timeoutSec)
                {
                    timer.Stop();
                    try {
                        if (!string.IsNullOrWhiteSpace(capturePath))
                        {
                            System.IO.File.WriteAllText(capturePath!, "OBS:" + t + Environment.NewLine + "EXP:" + expected);
                        }
                    } catch { }
                    Console.WriteLine("[TextSink] Timeout after " + timeoutSec + "s. Exiting with failure.");
                    try { if (hud != null && !hud.HasExited) hud.Kill(); } catch { }
                    Environment.Exit(1);
                }
            };
            timer.Start();
        };

        form.FormClosed += (_, __) =>
        {
            try { Console.WriteLine("[TextSink] Form closed. Killing HUD if still running."); } catch { }
            try { if (hud != null && !hud.HasExited) hud.Kill(); } catch { }
        };

        Application.Run(form);
    }

    private static void TryAttachConsole()
    {
        try { AttachConsole(ATTACH_PARENT_PROCESS); } catch { }
    }

    private const int ATTACH_PARENT_PROCESS = -1;
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AttachConsole(int dwProcessId);
    // no AllocConsole: avoid popping extra window
}

internal static class NativeMethods
{
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
