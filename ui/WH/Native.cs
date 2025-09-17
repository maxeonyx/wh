using System;
using System.Runtime.InteropServices;

namespace wh;

internal static class Native
{
    [DllImport("wh.dll", CharSet = CharSet.Unicode, ExactSpelling = false, SetLastError = true)]
    private static extern int wh_init([MarshalAs(UnmanagedType.LPWStr)] string model_path);

    [DllImport("wh.dll", CharSet = CharSet.Unicode, ExactSpelling = false, SetLastError = true)]
    private static extern int wh_transcribe_wav([MarshalAs(UnmanagedType.LPWStr)] string wav_path, out IntPtr out_utf16);

    [DllImport("wh.dll", CharSet = CharSet.Unicode, ExactSpelling = false, SetLastError = true)]
    private static extern void wh_free(IntPtr ptr);

    public static void Init(string modelPath)
    {
        var rc = wh_init(modelPath);
        if (rc != 0) throw new InvalidOperationException($"wh_init failed: {rc}");
    }

    public static string TranscribeWav(string path)
    {
        var rc = wh_transcribe_wav(path, out var p);
        if (rc != 0) throw new InvalidOperationException($"wh_transcribe_wav failed: {rc}");
        try
        {
            return Marshal.PtrToStringUni(p) ?? string.Empty;
        }
        finally
        {
            if (p != IntPtr.Zero) wh_free(p);
        }
    }
}
