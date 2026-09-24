using Amazon.Rekognition;
using Amazon.Rekognition.Model;
using CocoRider.Domain.Common;
using CocoRider.Domain.Verification;
using CocoRider.Infrastructure.Storage;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CocoRider.Infrastructure.DocumentChecks;

/// <summary>Result of the automatic check. Not accepted means "an admin must look", never "rejected".</summary>
public sealed record DocumentCheckResult(bool Accepted, string? Note)
{
    public static readonly DocumentCheckResult Pass = new(true, null);
    public static DocumentCheckResult Review(string note) => new(false, note);
}

public interface IDocumentChecker
{
    /// <param name="document">The document that was just submitted.</param>
    /// <param name="nationalId">The user's current CNI, used to compare faces with a selfie.</param>
    Task<DocumentCheckResult> CheckAsync(UserDocument document, UserDocument? nationalId, CancellationToken ct);
}

/// <summary>
/// Automatic checks with Amazon Rekognition, which reads the photos directly from the S3 bucket:
/// text detection to make sure the photo is the expected document, and face comparison between
/// the selfie and the CNI photo.
/// </summary>
public sealed class RekognitionDocumentChecker(
    IAmazonRekognition rekognition,
    IOptions<StorageOptions> storage,
    IOptions<PlatformPolicy> policy,
    ILogger<RekognitionDocumentChecker> logger) : IDocumentChecker
{
    public async Task<DocumentCheckResult> CheckAsync(UserDocument document, UserDocument? nationalId, CancellationToken ct)
    {
        try
        {
            return document.Type == DocumentType.Selfie
                ? await CompareFacesAsync(document, nationalId, ct)
                : await DetectTextAsync(document, ct);
        }
        catch (AmazonRekognitionException e)
        {
            // Unreadable image, unsupported format, throttling...: a human decides.
            logger.LogWarning(e, "Automatic check failed for document {DocumentId}", document.Id);
            return DocumentCheckResult.Review("automatic_check_failed");
        }
    }

    private async Task<DocumentCheckResult> DetectTextAsync(UserDocument document, CancellationToken ct)
    {
        if (!DocumentTextRules.HasTextCheck(document.Type))
            return DocumentCheckResult.Pass;

        var response = await rekognition.DetectTextAsync(new DetectTextRequest { Image = ImageOf(document) }, ct);
        var lines = (response.TextDetections ?? [])
            .Where(t => t.Type == TextTypes.LINE)
            .Select(t => t.DetectedText);

        return DocumentTextRules.LooksLike(document.Type, lines)
            ? DocumentCheckResult.Pass
            : DocumentCheckResult.Review("document_text_not_recognized");
    }

    private async Task<DocumentCheckResult> CompareFacesAsync(UserDocument selfie, UserDocument? nationalId, CancellationToken ct)
    {
        if (nationalId is null || nationalId.Status is DocumentStatus.AwaitingUpload or DocumentStatus.Rejected)
            return DocumentCheckResult.Review("national_id_missing");

        var threshold = policy.Value.FaceMatchThreshold;
        var response = await rekognition.CompareFacesAsync(new CompareFacesRequest
        {
            SourceImage = ImageOf(selfie),
            TargetImage = ImageOf(nationalId),
            SimilarityThreshold = threshold,
        }, ct);

        var best = (response.FaceMatches ?? []).Select(m => m.Similarity ?? 0f).DefaultIfEmpty(0f).Max();
        return best >= threshold
            ? DocumentCheckResult.Pass
            : DocumentCheckResult.Review($"face_match_below_threshold:{best:F0}");
    }

    private Image ImageOf(UserDocument document) => new()
    {
        S3Object = new S3Object { Bucket = storage.Value.DocumentsBucket, Name = document.StorageKey },
    };
}

/// <summary>Local development: accepts every document.</summary>
public sealed class AcceptAllDocumentChecker : IDocumentChecker
{
    public Task<DocumentCheckResult> CheckAsync(UserDocument document, UserDocument? nationalId, CancellationToken ct) =>
        Task.FromResult(DocumentCheckResult.Pass);
}
