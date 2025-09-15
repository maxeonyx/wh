using System;
using System.IO;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;
using System.Threading.Tasks;

namespace wh;

public static class ModelManager
{
    public sealed record Manifest(string FileName, string Sha256, long Size);

    public static string GetRuntimeRoot()
    {
        var overrideDir = Environment.GetEnvironmentVariable("WH_RUNTIME_DIR");
        if (!string.IsNullOrWhiteSpace(overrideDir)) return overrideDir!;
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return Path.Combine(local, "wh");
    }

    public static string GetModelsRoot()
    {
        var overrideDir = Environment.GetEnvironmentVariable("WH_MODELS_DIR");
        if (!string.IsNullOrWhiteSpace(overrideDir)) return overrideDir!;
        return Path.Combine(GetRuntimeRoot(), "models");
    }

    public static string GetLogsRoot()
    {
        var dir = Path.Combine(GetRuntimeRoot(), "logs");
        Directory.CreateDirectory(dir);
        return dir;
    }

    public static string DefaultModelFileName => "ggml-tiny.en.bin"; // small and fast for CI

    public static string GetModelPath() => Path.Combine(GetModelsRoot(), DefaultModelFileName);

    public static string GetManifestPath() => Path.Combine(GetModelsRoot(), DefaultModelFileName + ".manifest.json");

    public static string DefaultModelUrl =>
        Environment.GetEnvironmentVariable("WH_MODEL_URL") ??
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/" + DefaultModelFileName;

    public static async Task EnsureModelAsync(ILog log)
    {
        var root = GetModelsRoot();
        Directory.CreateDirectory(root);
        var dest = GetModelPath();
        var manifestPath = GetManifestPath();

        if (File.Exists(dest))
        {
            try
            {
                if (File.Exists(manifestPath))
                {
                    var manifest = JsonSerializer.Deserialize<Manifest>(await File.ReadAllTextAsync(manifestPath));
                    if (manifest != null)
                    {
                        using var fs = File.OpenRead(dest);
                        using var sha = SHA256.Create();
                        var hash = BitConverter.ToString(sha.ComputeHash(fs)).Replace("-", "").ToLowerInvariant();
                        if (string.Equals(hash, manifest.Sha256, StringComparison.OrdinalIgnoreCase))
                        {
                            log.Info("model.verify", ($"sha256", hash), ("size", fs.Length));
                            return;
                        }
                        else
                        {
                            log.Warn("model.hash_mismatch", ("expected", manifest.Sha256), ("actual", hash));
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                log.Warn("model.verify_failed", ("error", ex.Message));
            }
        }

        // Download
        var url = DefaultModelUrl;
        log.Info("model.download.start", ("url", url));
        var tmp = dest + ".downloading";
        using (var http = new HttpClient())
        using (var resp = await http.GetAsync(url))
        {
            resp.EnsureSuccessStatusCode();
            await using var outFs = File.Create(tmp);
            await resp.Content.CopyToAsync(outFs);
        }

        // Compute hash and finalize
        string sha256;
        long size;
        await using (var fs = File.OpenRead(tmp))
        {
            using var sha = SHA256.Create();
            sha256 = BitConverter.ToString(sha.ComputeHash(fs)).Replace("-", "").ToLowerInvariant();
            size = fs.Length;
        }
        Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
        if (File.Exists(dest)) File.Delete(dest);
        File.Move(tmp, dest);
        var manifest2 = new Manifest(Path.GetFileName(dest), sha256, size);
        await File.WriteAllTextAsync(manifestPath, JsonSerializer.Serialize(manifest2));
        log.Info("model.download.complete", ("path", dest), ("sha256", sha256), ("size", size));
    }
}
