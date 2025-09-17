using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace wh;

public interface ITextInjector
{
    // Insert at caret in the currently focused control
    void Insert(string text);
    // Replace the last injected segment of length charCount with new text
    void ReplaceLast(int charCount, string text);
}

// Strategy: Clipboard + Ctrl+V (kept for future investigations; not used in M3)
public sealed class ClipboardPasteInjector : ITextInjector
{
    private int _lastCount;

    public void Insert(string text)
    {
        // Not used by default; left in place for future milestones.
        Thread thread = new Thread(() => DoPaste(text));
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join();
        _lastCount = text?.Length ?? 0;
    }

    public void ReplaceLast(int charCount, string text)
    {
        if (charCount > 0)
        {
            for (int i = 0; i < charCount; i++) SendKeys.SendWait("+{LEFT}");
        }
        Insert(text);
    }

    private static void DoPaste(string text)
    {
        IDataObject? backup = null;
        try { backup = Clipboard.GetDataObject(); } catch { }
        try
        {
            Clipboard.SetText(text ?? string.Empty);
            SendKeys.SendWait("^v");
        }
        finally
        {
            if (backup != null) { try { Clipboard.SetDataObject(backup); } catch { } }
        }
    }
}

// Strategy: SendInput typing (default for M3)
public sealed class SendInputTextInjector : ITextInjector
{
    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion U;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx, dy, mouseData;
        public uint dwFlags, time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HARDWAREINPUT
    {
        public uint uMsg, wParamL, wParamH;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, [In] INPUT[] pInputs, int cbSize);

    private const uint INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const uint KEYEVENTF_UNICODE = 0x0004;
    private const ushort VK_BACK = 0x08;

    private int _lastCount;

    public void Insert(string text)
    {
        // Do not touch focus here; SendInput targets the current focus.
        // If nothing is focused, this is a programming/usage error and should fail upstream.

        // Use Unicode events for all characters (UTF-16 code units).
        // Handle surrogate pairs explicitly via Rune enumeration.
        var s = text ?? string.Empty;
        if (s.Length > 0)
        {
            var list = new System.Collections.Generic.List<INPUT>(s.Length * 2);

            foreach (var rune in s.EnumerateRunes())
            {
                if (rune.Value <= 0xFFFF)
                {
                    ushort cu = (ushort)rune.Value;
                    list.Add(DownUnicode(cu));
                    list.Add(UpUnicode(cu));
                }
                else
                {
                    // Split to surrogate pair characters
                    var pair = rune.ToString();
                    list.Add(DownUnicode(pair[0]));
                    list.Add(UpUnicode(pair[0]));
                    list.Add(DownUnicode(pair[1]));
                    list.Add(UpUnicode(pair[1]));
                }
            }

            var arr = list.ToArray();
            int cb = Marshal.SizeOf<INPUT>();
            uint sent = SendInput((uint)arr.Length, arr, cb);
            if (sent != arr.Length)
            {
                int err = Marshal.GetLastWin32Error();
                throw new InvalidOperationException($"SendInput failed: sent {sent} of {arr.Length} (err={err}, cbSize={cb})");
            }
        }
        _lastCount = s.Length;
    }

    public void ReplaceLast(int charCount, string text)
    {
        if (charCount > 0)
        {
            var backs = new System.Collections.Generic.List<INPUT>(charCount * 2);
            for (int i = 0; i < charCount; i++)
            {
                backs.Add(DownVk(VK_BACK));
                backs.Add(UpVk(VK_BACK));
            }
            var arr = backs.ToArray();
            var sent = SendInput((uint)arr.Length, arr, Marshal.SizeOf<INPUT>());
            if (sent != arr.Length)
            {
                int err = Marshal.GetLastWin32Error();
                throw new InvalidOperationException($"SendInput failed for backspaces: sent {sent} of {arr.Length} (err={err})");
            }
        }
        Insert(text);
    }

    private static INPUT DownUnicode(ushort codeUnit) => new INPUT
    {
        type = INPUT_KEYBOARD,
        U = new InputUnion
        {
            ki = new KEYBDINPUT
            {
                wVk = 0,
                wScan = codeUnit,
                dwFlags = KEYEVENTF_UNICODE,
                time = 0,
                dwExtraInfo = UIntPtr.Zero
            }
        }
    };

    private static INPUT UpUnicode(ushort codeUnit) => new INPUT
    {
        type = INPUT_KEYBOARD,
        U = new InputUnion
        {
            ki = new KEYBDINPUT
            {
                wVk = 0,
                wScan = codeUnit,
                dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                time = 0,
                dwExtraInfo = UIntPtr.Zero
            }
        }
    };

    private static INPUT DownVk(ushort vk) => new INPUT
    {
        type = INPUT_KEYBOARD,
        U = new InputUnion
        {
            ki = new KEYBDINPUT
            {
                wVk = vk,
                wScan = 0,
                dwFlags = 0,
                time = 0,
                dwExtraInfo = UIntPtr.Zero
            }
        }
    };

    private static INPUT UpVk(ushort vk) => new INPUT
    {
        type = INPUT_KEYBOARD,
        U = new InputUnion
        {
            ki = new KEYBDINPUT
            {
                wVk = vk,
                wScan = 0,
                dwFlags = KEYEVENTF_KEYUP,
                time = 0,
                dwExtraInfo = UIntPtr.Zero
            }
        }
    };
}
