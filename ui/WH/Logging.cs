using System;
using System.IO;
using System.Text;

namespace wh;

public interface ILog
{
    void Info(string evt, params (string key, object? val)[] fields);
    void Warn(string evt, params (string key, object? val)[] fields);
    void Error(string evt, params (string key, object? val)[] fields);
}

public sealed class FileLogger : ILog, IDisposable
{
    private readonly object _gate = new();
    private readonly StreamWriter _writer;

    public FileLogger(string path)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        _writer = new StreamWriter(new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.Read))
        {
            AutoFlush = true
        };
        Info("log.open", ("path", path));
    }

    public void Info(string evt, params (string key, object? val)[] fields) => Write("INFO", evt, fields);
    public void Warn(string evt, params (string key, object? val)[] fields) => Write("WARN", evt, fields);
    public void Error(string evt, params (string key, object? val)[] fields) => Write("ERROR", evt, fields);

    private void Write(string level, string evt, params (string key, object? val)[] fields)
    {
        var ts = DateTimeOffset.Now.ToString("o");
        var sb = new StringBuilder();
        sb.Append(ts).Append(' ').Append(level).Append(' ').Append(evt);
        foreach (var f in fields)
        {
            sb.Append(' ').Append(f.key).Append('=').Append('"').Append(f.val).Append('"');
        }
        lock (_gate)
        {
            _writer.WriteLine(sb.ToString());
        }
    }

    public void Dispose()
    {
        try { _writer?.Dispose(); } catch { }
    }
}

