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

/// <summary>Local development: pretends every upload succeeded.</summary>
public sealed class FakeDocumentStorage : IDocumentStorage
{
    public Task<Uri> CreateUploadUrlAsync(string key, string contentType, CancellationToken ct) =>
        Task.FromResult(new Uri($"http://localhost/fake-upload/{key}"));

    public Task<Uri> CreateDownloadUrlAsync(string key, CancellationToken ct) =>
        Task.FromResult(new Uri($"http://localhost/fake-download/{key}"));

    public Task<StoredObject?> GetMetadataAsync(string key, CancellationToken ct) =>
        Task.FromResult<StoredObject?>(new StoredObject(1024, "image/jpeg"));
}
