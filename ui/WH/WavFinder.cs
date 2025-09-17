using System;
using System.IO;

namespace wh;

internal static class WavFinder
{
    // Finds the default test WAV used by both headless and UI flows.
    // Looks for assets/audio/hello.wav starting from baseDir and walking up to 4 parents.
    public static string FindHelloWavOrThrow(string baseDir)
    {
        var path = FindHelloWav(baseDir);
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
            throw new InvalidOperationException("No WAV found at assets/audio/hello.wav.");
        return path!;
    }

    public static string? FindHelloWav(string baseDir)
    {
        string? wav = null;
        var dir = baseDir;
        for (int i = 0; i < 4 && string.IsNullOrEmpty(wav); i++)
        {
            var candidate = Path.GetFullPath(Path.Combine(dir, "assets", "audio", "hello.wav"));
            if (File.Exists(candidate)) { wav = candidate; break; }
            var parent = Directory.GetParent(dir)?.FullName;
            if (string.IsNullOrEmpty(parent)) break;
            dir = parent!;
        }
        return wav;
    }
}

