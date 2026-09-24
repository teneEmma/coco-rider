using CocoRider.Domain.Users;

namespace CocoRider.Domain.Verification;

/// <summary>Which documents each role needs. Bound from the "Verification" configuration section.</summary>
public sealed class VerificationRequirements
{
    public List<DocumentType> Passenger { get; set; } = [DocumentType.NationalId, DocumentType.Selfie];

    public List<DocumentType> Driver { get; set; } =
    [
        DocumentType.NationalId,
        DocumentType.Selfie,
        DocumentType.DriverLicence,
        DocumentType.Insurance,
        DocumentType.VehicleRegistration,
    ];

    public IReadOnlyList<DocumentType> For(VerificationRole role) => role == VerificationRole.Driver ? Driver : Passenger;
}

public sealed record VerificationOutcome(
    VerificationStatus Status,
    IReadOnlyList<DocumentType> Missing,
    IReadOnlyList<DocumentType> Expired);

public static class VerificationRules
{
    /// <summary>
    /// Derives a role's verification status from the user's current (non-superseded) documents.
    /// Rejected wins over missing, missing over manual review.
    /// </summary>
    public static VerificationOutcome Evaluate(
        IEnumerable<UserDocument> documents,
        IReadOnlyList<DocumentType> required,
        DateOnly today)
    {
        var current = documents
            .Where(d => !d.IsSuperseded)
            .GroupBy(d => d.Type)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(d => d.CreatedAt).First());

        var missing = new List<DocumentType>();
        var expired = new List<DocumentType>();
        var rejected = false;
        var needsReview = false;

        foreach (var type in required)
        {
            if (!current.TryGetValue(type, out var doc) || doc.Status is DocumentStatus.AwaitingUpload)
            {
                missing.Add(type);
                continue;
            }

            if (doc.IsExpired(today))
            {
                expired.Add(type);
                continue;
            }

            switch (doc.Status)
            {
                case DocumentStatus.Rejected:
                    rejected = true;
                    break;
                case DocumentStatus.Submitted or DocumentStatus.NeedsReview:
                    needsReview = true;
                    break;
            }
        }

        var status = rejected ? VerificationStatus.Rejected
            : missing.Count > 0 || expired.Count > 0 ? VerificationStatus.Incomplete
            : needsReview ? VerificationStatus.ManualReview
            : VerificationStatus.Verified;

        return new VerificationOutcome(status, missing, expired);
    }
}
