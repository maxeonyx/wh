using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;

namespace wh;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        TryShowNativeHello();
    }

    [DllImport("wh.dll", CharSet = CharSet.Unicode, ExactSpelling = false, SetLastError = true)]
    private static extern IntPtr wh_hello();

    private void TryShowNativeHello()
    {
        try
        {
            // Attempt to call native stub if available (extracted in single-file publish).
            var ptr = wh_hello();
            if (ptr != IntPtr.Zero)
            {
                string msg = Marshal.PtrToStringUni(ptr) ?? string.Empty;
                NativeHello.Text = $"Native says: {msg}";
            }
            else
            {
                NativeHello.Text = "Native stub not available (null pointer).";
            }
        }
        catch (DllNotFoundException)
        {
            NativeHello.Text = "Native stub (wh.dll) not found — OK for M1.";
        }
        catch (Exception ex)
        {
            NativeHello.Text = $"Native call failed: {ex.Message}";
        }
    }

    private void OnRecordClick(object sender, RoutedEventArgs e)
    {
        MessageBox.Show("Record pressed — wiring arrives in M2.", "wh");
    }
}

