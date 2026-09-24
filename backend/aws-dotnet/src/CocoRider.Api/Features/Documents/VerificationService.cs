using CocoRider.Domain.Users;
using CocoRider.Domain.Verification;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CocoRider.Api.Features.Documents;

public sealed record RoleVerification(VerificationStatus Status, IReadOnlyList<DocumentType> Required,
    IReadOnlyList<DocumentType> Missing, IReadOnlyList<DocumentType> Expired);

/// <summary>Keeps a user's passenger/driver status in sync with their documents.</summary>
public sealed class VerificationService(CocoRiderDbContext db, IOptions<VerificationRequirements> requirements, TimeProvider clock)
{
    public Task<List<UserDocument>> CurrentDocumentsAsync(Guid userId, CancellationToken ct) =>
        db.Documents.Where(d => d.UserId == userId && !d.IsSuperseded).OrderBy(d => d.Type).ToListAsync(ct);

    /// <summary>
    /// Re-evaluates both roles. Called after every document change and before publishing or
    /// booking a trip, so that an expired licence or insurance takes effect without a batch job.
    /// </summary>
    public async Task<Dictionary<VerificationRole, RoleVerification>> RefreshAsync(User user, CancellationToken ct)
    {
        var documents = await CurrentDocumentsAsync(user.Id, ct);
        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var result = new Dictionary<VerificationRole, RoleVerification>();

        foreach (var role in Enum.GetValues<VerificationRole>())
        {
            var required = requirements.Value.For(role);
            var outcome = VerificationRules.Evaluate(documents, required, today);
            user.SetVerificationStatus(role, outcome.Status);
            result[role] = new RoleVerification(outcome.Status, required, outcome.Missing, outcome.Expired);
        }

        return result;
    }
}
