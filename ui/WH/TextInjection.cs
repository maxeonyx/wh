using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace wh;

public interface ITextInjector
{
    void Inject(string text);
}

// Strategy 1: Clipboard + Ctrl+V
public sealed class ClipboardPasteInjector : ITextInjector
{
    public void Inject(string text)
    {
        Thread thread = new Thread(() => DoInject(text));
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join();
    }

    private void DoInject(string text)
    {
        IDataObject? backup = null;
        try
        {
            backup = Clipboard.GetDataObject();
        }
        catch { /* ignore */ }
        try
        {
            Clipboard.SetText(text);
            SendKeys.SendWait("^v");
        }
        finally
        {
            if (backup != null)
            {
                try { Clipboard.SetDataObject(backup); } catch { }
            }
        }
    }
}

// Strategy 2: SendInput typing fallback
public sealed class SendInputInjector : ITextInjector
{
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT
    {
        public int type;
        public InputUnion U;
    }

    [StructLayout(LayoutKind.Explicit)]
    struct InputUnion
    {
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT
    {
        public short wVk;
        public short wScan;
        public int dwFlags;
        public int time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    const int INPUT_KEYBOARD = 1;
    const int KEYEVENTF_UNICODE = 0x0004;
    const int KEYEVENTF_KEYUP = 0x0002;

    public void Inject(string text)
    {
        var inputs = new System.Collections.Generic.List<INPUT>();
        foreach (var ch in text)
        {
            inputs.Add(new INPUT { type = INPUT_KEYBOARD, U = new InputUnion { ki = new KEYBDINPUT { wScan = (short)ch, dwFlags = KEYEVENTF_UNICODE } } });
            inputs.Add(new INPUT { type = INPUT_KEYBOARD, U = new InputUnion { ki = new KEYBDINPUT { wScan = (short)ch, dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP } } });
        }
        SendInput((uint)inputs.Count, inputs.ToArray(), Marshal.SizeOf<INPUT>());
    }
}

