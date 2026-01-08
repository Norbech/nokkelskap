using System.Text.Json;
using Microsoft.AspNetCore.Components.Forms;

namespace KeyCabinetApp.Web.Services;

public sealed class KeyImageService
{
    private readonly object _gate = new();
    private Dictionary<int, string> _map = new();

    private readonly string _dataDir;
    private readonly string _imagesDir;
    private readonly string _mapPath;

    public KeyImageService()
    {
        _dataDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "KeyCabinetApp");

        _imagesDir = Path.Combine(_dataDir, "key-images");
        _mapPath = Path.Combine(_imagesDir, "map.json");

        Directory.CreateDirectory(_imagesDir);
        LoadMap();
    }

    public string? GetImageUrl(int keyId)
    {
        lock (_gate)
        {
            if (!_map.TryGetValue(keyId, out var fileName) || string.IsNullOrWhiteSpace(fileName))
            {
                return null;
            }

            return $"/key-images/{Uri.EscapeDataString(fileName)}";
        }
    }

    public async Task<(bool ok, string? error)> SaveAsync(int keyId, IBrowserFile file, long maxBytes = 5 * 1024 * 1024)
    {
        if (keyId <= 0) return (false, "Ugyldig nøkkel-id");
        if (file is null) return (false, "Ingen fil");

        if (file.Size <= 0) return (false, "Tom fil");
        if (file.Size > maxBytes) return (false, $"Filen er for stor (maks {maxBytes / (1024 * 1024)} MB)");

        if (string.IsNullOrWhiteSpace(file.ContentType) || !file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            return (false, "Filen må være et bilde (image/*)");
        }

        var ext = Path.GetExtension(file.Name);
        if (string.IsNullOrWhiteSpace(ext)) ext = ContentTypeToExtension(file.ContentType);
        ext = NormalizeExtension(ext);

        var fileName = $"{keyId}{ext}";
        var fullPath = Path.Combine(_imagesDir, fileName);

        try
        {
            await using var output = File.Create(fullPath);
            await using var input = file.OpenReadStream(maxAllowedSize: maxBytes);
            await input.CopyToAsync(output);

            lock (_gate)
            {
                _map[keyId] = fileName;
                PersistMap();
            }

            return (true, null);
        }
        catch (Exception ex)
        {
            return (false, ex.Message);
        }
    }

    public (bool ok, string? error) Remove(int keyId)
    {
        if (keyId <= 0) return (false, "Ugyldig nøkkel-id");

        try
        {
            string? fileName;
            lock (_gate)
            {
                if (!_map.TryGetValue(keyId, out fileName))
                {
                    return (true, null);
                }
                _map.Remove(keyId);
                PersistMap();
            }

            if (!string.IsNullOrWhiteSpace(fileName))
            {
                var fullPath = Path.Combine(_imagesDir, fileName);
                if (File.Exists(fullPath)) File.Delete(fullPath);
            }

            return (true, null);
        }
        catch (Exception ex)
        {
            return (false, ex.Message);
        }
    }

    private void LoadMap()
    {
        lock (_gate)
        {
            _map = new Dictionary<int, string>();

            if (!File.Exists(_mapPath)) return;

            try
            {
                var json = File.ReadAllText(_mapPath);
                var parsed = JsonSerializer.Deserialize<Dictionary<int, string>>(json);
                if (parsed is not null) _map = parsed;
            }
            catch
            {
                // ignore broken map.json
                _map = new Dictionary<int, string>();
            }
        }
    }

    private void PersistMap()
    {
        var json = JsonSerializer.Serialize(_map, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(_mapPath, json);
    }

    private static string NormalizeExtension(string ext)
    {
        ext = ext.Trim();
        if (!ext.StartsWith('.')) ext = "." + ext;
        ext = ext.ToLowerInvariant();

        return ext switch
        {
            ".jpg" => ".jpg",
            ".jpeg" => ".jpeg",
            ".png" => ".png",
            ".webp" => ".webp",
            ".gif" => ".gif",
            _ => ".png",
        };
    }

    private static string ContentTypeToExtension(string contentType)
    {
        return contentType.ToLowerInvariant() switch
        {
            "image/jpeg" => ".jpg",
            "image/png" => ".png",
            "image/webp" => ".webp",
            "image/gif" => ".gif",
            _ => ".png",
        };
    }
}
