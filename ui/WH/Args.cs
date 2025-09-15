using System;
using System.Linq;

namespace wh;

public sealed class Args
{
    public string? E2eWavPath { get; set; }
    public bool IsE2e => !string.IsNullOrWhiteSpace(E2eWavPath);

    public static Args Parse(string[] args)
    {
        var a = new Args();
        for (int i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (arg == "--e2e-wav" && i + 1 < args.Length)
            {
                a.E2eWavPath = args[++i];
                continue;
            }
        }
        return a;
    }
}
