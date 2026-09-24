using System.Collections.Concurrent;
using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.Extensions.Options;

namespace CocoRider.Infrastructure.Storage;

public sealed class StorageOptions
{
    /// <summary>"S3" in AWS, "Fake" for local development and tests.</summary>
    public string Mode { get; set; } = "S3";

    /// <summary>Private bucket holding identity documents (never public).</summary>
    public string DocumentsBucket { get; set; } = "";

    public int UploadUrlMinutes { get; set; } = 10;
    public int DownloadUrlMinutes { get; set; } = 5;
    public long MaxDocumentBytes { get; set; } = 10 * 1024 * 1024;

    /// <summary>Fake mode only: public URL of the local API, used in upload/download URLs.</summary>
    public string FakeBaseUrl { get; set; } = "http://localhost:5200";
}

/// <summary>Metadata of a stored object, or null when nothing was uploaded.</summary>
public sealed record StoredObject(long SizeBytes, string? ContentType);

public interface IDocumentStorage
{
    /// <summary>A short-lived URL the mobile app uses to PUT the photo straight to storage.</summary>
    Task<Uri> CreateUploadUrlAsync(string key, string contentType, CancellationToken ct);

    /// <summary>A short-lived URL the admin dashboard uses to display the photo.</summary>
    Task<Uri> CreateDownloadUrlAsync(string key, CancellationToken ct);

    Task<StoredObject?> GetMetadataAsync(string key, CancellationToken ct);
}

public sealed class S3DocumentStorage(IAmazonS3 s3, IOptions<StorageOptions> options) : IDocumentStorage
{
    private readonly StorageOptions _options = options.Value;

    public async Task<Uri> CreateUploadUrlAsync(string key, string contentType, CancellationToken ct)
    {
        var url = await s3.GetPreSignedURLAsync(new GetPreSignedUrlRequest
        {
            BucketName = _options.DocumentsBucket,
            Key = key,
            Verb = HttpVerb.PUT,
            ContentType = contentType,
            Expires = DateTime.UtcNow.AddMinutes(_options.UploadUrlMinutes),
        });
        return new Uri(url);
    }

    public async Task<Uri> CreateDownloadUrlAsync(string key, CancellationToken ct)
    {
        var url = await s3.GetPreSignedURLAsync(new GetPreSignedUrlRequest
        {
            BucketName = _options.DocumentsBucket,
            Key = key,
            Verb = HttpVerb.GET,
            Expires = DateTime.UtcNow.AddMinutes(_options.DownloadUrlMinutes),
        });
        return new Uri(url);
    }

    public async Task<StoredObject?> GetMetadataAsync(string key, CancellationToken ct)
    {
        try
        {
            var metadata = await s3.GetObjectMetadataAsync(_options.DocumentsBucket, key, ct);
            return new StoredObject(metadata.ContentLength, metadata.Headers.ContentType);
        }
        catch (AmazonS3Exception e) when (e.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }
}

/// <summary>
/// Local development: photos are kept in memory and served by the API itself
/// (PUT/GET /dev/uploads/{key}, mapped only in Development), so the app and the
/// admin dashboard can be tried without AWS.
/// </summary>
public sealed class FakeDocumentStorage(IOptions<StorageOptions> options) : IDocumentStorage
{
    private readonly ConcurrentDictionary<string, (byte[] Bytes, string ContentType)> _objects = new();

    private string BaseUrl => options.Value.FakeBaseUrl.TrimEnd('/');

    public Task<Uri> CreateUploadUrlAsync(string key, string contentType, CancellationToken ct) =>
        Task.FromResult(new Uri($"{BaseUrl}/dev/uploads/{key}"));

    public Task<Uri> CreateDownloadUrlAsync(string key, CancellationToken ct) =>
        Task.FromResult(new Uri($"{BaseUrl}/dev/uploads/{key}"));

    /// <summary>Lenient: documents submitted without an upload (API tests) count as a small photo.</summary>
    public Task<StoredObject?> GetMetadataAsync(string key, CancellationToken ct) =>
        Task.FromResult<StoredObject?>(_objects.TryGetValue(key, out var stored)
            ? new StoredObject(stored.Bytes.Length, stored.ContentType)
            : new StoredObject(1024, "image/jpeg"));

    public void Put(string key, byte[] bytes, string contentType) => _objects[key] = (bytes, contentType);

    public (byte[] Bytes, string ContentType)? Get(string key) =>
        _objects.TryGetValue(key, out var stored) ? stored : null;
}
