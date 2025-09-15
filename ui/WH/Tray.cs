using System;
using System.Drawing;
using System.Windows.Forms;

namespace wh;

public sealed class Tray : IDisposable
{
    private readonly NotifyIcon _icon;
    private readonly Action _onRestore;
    private readonly Action _onExit;

    public Tray(Action onRestore, Action onExit)
    {
        _onRestore = onRestore;
        _onExit = onExit;
        _icon = new NotifyIcon
        {
            Text = "wh - Whisper HUD",
            Icon = SystemIcons.Application,
            Visible = true,
            ContextMenuStrip = new ContextMenuStrip()
        };
        _icon.ContextMenuStrip.Items.Add("Open", null, (_, __) => _onRestore());
        _icon.ContextMenuStrip.Items.Add("Exit", null, (_, __) => _onExit());
        _icon.DoubleClick += (_, __) => _onRestore();
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.Dispose();
    }
}

