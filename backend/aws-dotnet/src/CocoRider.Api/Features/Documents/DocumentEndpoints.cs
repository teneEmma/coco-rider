using CocoRider.Api.Auth;
using CocoRider.Domain.Common;
using CocoRider.Domain.Verification;
using CocoRider.Infrastructure.DocumentChecks;
using CocoRider.Infrastructure.Persistence;
using CocoRider.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CocoRider.Api.Features.Documents;

public sealed record CreateDocumentRequest(DocumentType Type, string ContentType);

public sealed record CreateDocumentResponse(Guid DocumentId, Uri UploadUrl, string ContentType, DateTimeOffset UploadUrlExpiresAt);

public sealed record SubmitDocumentRequest(DateOnly? ExpiresOn);

public sealed record DocumentResponse(Guid Id, DocumentType Type, DocumentStatus Status, DateOnly? ExpiresOn,
    string? ReviewNote, DateTimeOffset UpdatedAt)
{
    public static DocumentResponse From(UserDocument d) => new(d.Id, d.Type, d.Status, d.ExpiresOn, d.ReviewNote, d.UpdatedAt);
}

/// <summary>
/// Upload flow: 1) POST /v1/me/documents to get a pre-signed S3 URL, 2) the app PUTs the photo
/// to S3, 3) POST /v1/me/documents/{id}/submit runs the automatic checks.
/// </summary>
public static class DocumentEndpoints
{
    /// <summary>Amazon Rekognition only reads JPEG and PNG.</summary>
    private static readonly Dictionary<string, string> Extensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["image/jpeg"] = "jpg",
        ["image/png"] = "png",
    };

    public static void MapDocumentEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/v1/me/documents").WithTags("Documents");
        group.MapGet("/", ListAsync);
        group.MapPost("/", CreateAsync);
        group.MapPost("/{id:guid}/submit", SubmitAsync);
    }

    private static async Task<IEnumerable<DocumentResponse>> ListAsync(CurrentUser current, VerificationService verification, CancellationToken ct)
    {
        var user = await current.RequireProfileAsync(ct);
        var documents = await verification.CurrentDocumentsAsync(user.Id, ct);
        return documents.Select(DocumentResponse.From);
    }

    private static async Task<CreateDocumentResponse> CreateAsync(CreateDocumentRequest request, CurrentUser current,
        CocoRiderDbContext db, IDocumentStorage storage, IOptions<StorageOptions> storageOptions, TimeProvider clock, CancellationToken ct)
    {
        if (!Extensions.TryGetValue(request.ContentType, out var extension))
            throw new DomainException("document.unsupported_format", "Only JPEG and PNG photos are accepted.");

        var user = await current.RequireProfileAsync(ct);
        var now = clock.GetUtcNow();
        var contentType = request.ContentType.ToLowerInvariant();
        var key = $"users/{user.Id}/{request.Type}/{Guid.NewGuid()}.{extension}";

        var document = new UserDocument(user.Id, request.Type, key, contentType, now);
        db.Documents.Add(document);
        await db.SaveChangesAsync(ct);

        var url = await storage.CreateUploadUrlAsync(key, contentType, ct);
        return new CreateDocumentResponse(document.Id, url, contentType, now.AddMinutes(storageOptions.Value.UploadUrlMinutes));
    }

    private static async Task<DocumentResponse> SubmitAsync(Guid id, SubmitDocumentRequest request, CurrentUser current,
        CocoRiderDbContext db, IDocumentStorage storage, IDocumentChecker checker, VerificationService verification,
        IOptions<StorageOptions> storageOptions, TimeProvider clock, CancellationToken ct)
    {
        var user = await current.RequireProfileAsync(ct);
        var document = await db.Documents.FirstOrDefaultAsync(d => d.Id == id && d.UserId == user.Id, ct)
            ?? throw new NotFoundException("document.not_found", "Document not found.");

        var stored = await storage.GetMetadataAsync(document.StorageKey, ct)
            ?? throw new DomainException("document.not_uploaded", "The photo has not been uploaded yet.");
        if (stored.SizeBytes > storageOptions.Value.MaxDocumentBytes)
            throw new DomainException("document.too_large", "The photo is too large.");

        var now = clock.GetUtcNow();
        document.Submit(request.ExpiresOn, DateOnly.FromDateTime(now.UtcDateTime), now);

        // The new upload replaces any previous document of the same type.
        var previous = await db.Documents
            .Where(d => d.UserId == user.Id && d.Type == document.Type && d.Id != document.Id && !d.IsSuperseded)
            .ToListAsync(ct);
        previous.ForEach(d => d.Supersede(now));

        var nationalId = document.Type == DocumentType.Selfie
            ? await db.Documents
                .Where(d => d.UserId == user.Id && d.Type == DocumentType.NationalId && !d.IsSuperseded)
                .OrderByDescending(d => d.CreatedAt)
                .FirstOrDefaultAsync(ct)
            : null;

        var check = await checker.CheckAsync(document, nationalId, ct);
        document.ApplyAutomaticCheck(check.Accepted, check.Note, now);

        await db.SaveChangesAsync(ct);
        await verification.RefreshAsync(user, ct);
        await db.SaveChangesAsync(ct);

        return DocumentResponse.From(document);
    }
}
