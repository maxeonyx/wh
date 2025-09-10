using System;
using System.Runtime.InteropServices;

namespace wh.Services
{
    public class EngineService : IDisposable
    {
        private const string DllName = "engine";

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern int wh_init(string modelPath);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr wh_transcribe(float[] samples, int count);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern void wh_free_result(IntPtr result);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern void wh_shutdown();

        public void LoadModel(string path)
        {
            if (wh_init(path) != 0)
            {
                throw new InvalidOperationException("Failed to load model");
            }
        }

        public string Transcribe(float[] samples)
        {
            IntPtr ptr = wh_transcribe(samples, samples.Length);
            if (ptr == IntPtr.Zero)
                return string.Empty;
            string text = Marshal.PtrToStringAnsi(ptr) ?? string.Empty;
            wh_free_result(ptr);
            return text;
        }

        public void Dispose()
        {
            wh_shutdown();
            GC.SuppressFinalize(this);
        }
    }
}
