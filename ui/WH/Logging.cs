using System;
using System.Text;

namespace wh;

public interface ILog
{
    void Info(string evt, params (string key, object? val)[] fields);
    void Warn(string evt, params (string key, object? val)[] fields);
    void Error(string evt, params (string key, object? val)[] fields);
}

public sealed class ConsoleLogger : ILog
{
    private static string Format(string level, string evt, params (string key, object? val)[] fields)
    {
        var ts = DateTimeOffset.Now.ToString("o");
        var sb = new StringBuilder();
        sb.Append(ts).Append(' ').Append(level).Append(' ').Append(evt);
        foreach (var f in fields)
        {
            sb.Append(' ').Append(f.key).Append('=').Append('"').Append(f.val).Append('"');
        }
        return sb.ToString();
    }

    private static void Write(string line)
    {
        try { Console.WriteLine(line); }
        catch { }
    }

    public void Info(string evt, params (string key, object? val)[] fields) => Write(Format("INFO", evt, fields));
    public void Warn(string evt, params (string key, object? val)[] fields) => Write(Format("WARN", evt, fields));
    public void Error(string evt, params (string key, object? val)[] fields) => Write(Format("ERROR", evt, fields));
}

public sealed class CompositeLogger : ILog, IDisposable
{
    private readonly ILog[] _sinks;
    public CompositeLogger(params ILog[] sinks) { _sinks = sinks; }
    public void Info(string evt, params (string key, object? val)[] fields) { foreach (var s in _sinks) s.Info(evt, fields); }
    public void Warn(string evt, params (string key, object? val)[] fields) { foreach (var s in _sinks) s.Warn(evt, fields); }
    public void Error(string evt, params (string key, object? val)[] fields) { foreach (var s in _sinks) s.Error(evt, fields); }
    public void Dispose()
    {
        foreach (var s in _sinks)
            if (s is IDisposable d) try { d.Dispose(); } catch { }
    }
}
