using System;
using System.IO;
using System.Net.Http;
using System.Security.Cryptography;
using System.Threading.Tasks;

namespace wh.Services
{
    // External Reference: OpenWhispr - https://github.com/HeroTools/open-whispr
    public class ModelManager
    {
        private static readonly HttpClient _http = new HttpClient();
        private readonly string _modelDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "wh", "models");

        private readonly (string Url, string Sha256) _smallModel = (
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
            "sha256-placeholder"
        );

        public async Task<string> EnsureModelAsync()
        {
            Directory.CreateDirectory(_modelDir);
            string path = Path.Combine(_modelDir, "ggml-small.bin");
            if (!File.Exists(path) || !VerifyHash(path, _smallModel.Sha256))
            {
                using var response = await _http.GetAsync(_smallModel.Url, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();
                using var fs = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
                await response.Content.CopyToAsync(fs);
            }
            return path;
        }

        private static bool VerifyHash(string path, string expected)
        {
            if (string.IsNullOrEmpty(expected) || !File.Exists(path))
                return false;
            using var sha = SHA256.Create();
            using var fs = File.OpenRead(path);
            var hash = BitConverter.ToString(sha.ComputeHash(fs)).Replace("-", string.Empty).ToLowerInvariant();
            return hash == expected.ToLowerInvariant();
        }
    }
}
