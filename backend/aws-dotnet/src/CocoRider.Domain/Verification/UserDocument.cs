using CocoRider.Domain.Common;

namespace CocoRider.Domain.Verification;

public enum DocumentType
{
    /// <summary>Carte Nationale d'Identité (CNI).</summary>
    NationalId,

    /// <summary>A photo of the user's face, compared with the CNI photo.</summary>
    Selfie,

    /// <summary>Permis de conduire.</summary>
    DriverLicence,

    /// <summary>Attestation d'assurance.</summary>
    Insurance,

    /// <summary>Carte grise (certificat d'immatriculation).</summary>
    VehicleRegistration,
}

public enum DocumentStatus
{
    /// <summary>An upload URL was issued; the file may not be in storage yet.</summary>
    AwaitingUpload,

    /// <summary>Uploaded and waiting for the automatic checks.</summary>
    Submitted,

    Accepted,

    /// <summary>The automatic checks were not conclusive; an admin must decide.</summary>
    NeedsReview,

    Rejected,
}

public sealed class UserDocument
{
    private UserDocument() { }

    public UserDocument(Guid userId, DocumentType type, string storageKey, string contentType, DateTimeOffset now)
    {
        Id = Guid.NewGuid();
        UserId = userId;
        Type = type;
        StorageKey = storageKey;
        ContentType = contentType;
        Status = DocumentStatus.AwaitingUpload;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }
    public Guid UserId { get; private set; }
    public DocumentType Type { get; private set; }

    /// <summary>S3 object key of the uploaded image.</summary>
    public string StorageKey { get; private set; } = null!;

    public string ContentType { get; private set; } = null!;
    public DocumentStatus Status { get; private set; }

    /// <summary>Expiry date typed by the user (licence, insurance, CNI). Null for documents that do not expire.</summary>
    public DateOnly? ExpiresOn { get; private set; }

    /// <summary>Why the automatic check or the admin did not accept the document.</summary>
    public string? ReviewNote { get; private set; }

    /// <summary>Cognito sub of the admin who took the last manual decision.</summary>
    public string? ReviewedBy { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }

    /// <summary>Documents superseded by a newer upload of the same type are kept for audit but ignored.</summary>
    public bool IsSuperseded { get; private set; }

    public bool IsExpired(DateOnly today) => ExpiresOn is { } expiry && expiry < today;

    public void Submit(DateOnly? expiresOn, DateOnly today, DateTimeOffset now)
    {
        if (Status != DocumentStatus.AwaitingUpload)
            throw new DomainException("document.already_submitted", "This document was already submitted.");
        if (expiresOn is { } expiry && expiry < today)
            throw new DomainException("document.expired", "This document is expired.");
        if (RequiresExpiryDate(Type) && expiresOn is null)
            throw new DomainException("document.expiry_required", "The expiry date of this document is required.");

        ExpiresOn = expiresOn;
        Status = DocumentStatus.Submitted;
        UpdatedAt = now;
    }

    public void ApplyAutomaticCheck(bool accepted, string? note, DateTimeOffset now)
    {
        if (Status != DocumentStatus.Submitted)
            throw new DomainException("document.not_submitted", "Only submitted documents can be checked.");

        Status = accepted ? DocumentStatus.Accepted : DocumentStatus.NeedsReview;
        ReviewNote = note;
        UpdatedAt = now;
    }

    public void Approve(string adminSub, DateTimeOffset now) => Decide(DocumentStatus.Accepted, adminSub, null, now);

    public void Reject(string adminSub, string reason, DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(reason))
            throw new DomainException("document.rejection_reason_required", "A rejection reason is required.");
        Decide(DocumentStatus.Rejected, adminSub, reason, now);
    }

    public void Supersede(DateTimeOffset now)
    {
        IsSuperseded = true;
        UpdatedAt = now;
    }

    public static bool RequiresExpiryDate(DocumentType type) =>
        type is DocumentType.DriverLicence or DocumentType.Insurance;

    private void Decide(DocumentStatus status, string adminSub, string? note, DateTimeOffset now)
    {
        if (Status is DocumentStatus.AwaitingUpload)
            throw new DomainException("document.not_submitted", "The document has not been submitted yet.");

        Status = status;
        ReviewNote = note;
        ReviewedBy = adminSub;
        UpdatedAt = now;
    }
}
