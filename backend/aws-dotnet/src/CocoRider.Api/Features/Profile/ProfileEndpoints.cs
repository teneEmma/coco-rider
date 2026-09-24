using System.Text.RegularExpressions;
using CocoRider.Api.Auth;
using CocoRider.Api.Features.Documents;
using CocoRider.Domain.Common;
using CocoRider.Domain.Users;
using CocoRider.Infrastructure.Persistence;

namespace CocoRider.Api.Features.Profile;

public sealed record UpsertProfileRequest(string FirstName, string LastName, Gender Gender, Language Language);

public sealed record ProfileResponse(
    Guid Id,
    string PhoneNumber,
    string FirstName,
    string LastName,
    Gender Gender,
    Language Language,
    RoleVerification Passenger,
    RoleVerification Driver,
    DateTimeOffset? SuspendedUntil,
    DateTimeOffset CreatedAt);

public static partial class ProfileEndpoints
{
    public static void MapProfileEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/v1/me").WithTags("Profile");
        group.MapGet("/", GetAsync);
        group.MapPut("/", UpsertAsync);
    }

    private static async Task<ProfileResponse> GetAsync(CurrentUser current, VerificationService verification, CancellationToken ct)
    {
        var user = await current.RequireProfileAsync(ct);
        return await ToResponseAsync(user, verification, ct);
    }

    /// <summary>Creates the profile on first call (right after the SMS sign-up), then updates it.</summary>
    private static async Task<ProfileResponse> UpsertAsync(UpsertProfileRequest request, CurrentUser current,
        CocoRiderDbContext db, VerificationService verification, TimeProvider clock, CancellationToken ct)
    {
        var user = await current.FindProfileAsync(ct);
        if (user is null)
        {
            var phone = current.PhoneNumber;
            if (phone is null || !CameroonPhone().IsMatch(phone))
                throw new DomainException("profile.invalid_phone", "A verified Cameroonian phone number (+237) is required.");

            user = new User(current.Sub, phone, request.FirstName, request.LastName, request.Gender, request.Language, clock.GetUtcNow());
            db.Users.Add(user);
        }
        else
        {
            user.UpdateProfile(request.FirstName, request.LastName, request.Gender, request.Language);
        }

        var response = await ToResponseAsync(user, verification, ct);
        await db.SaveChangesAsync(ct);
        return response;
    }

    internal static async Task<ProfileResponse> ToResponseAsync(User user, VerificationService verification, CancellationToken ct)
    {
        var roles = await verification.RefreshAsync(user, ct);
        return new ProfileResponse(user.Id, user.PhoneNumber, user.FirstName, user.LastName, user.Gender, user.Language,
            roles[VerificationRole.Passenger], roles[VerificationRole.Driver], user.SuspendedUntil, user.CreatedAt);
    }

    /// <summary>Cameroonian numbers: +237 followed by 9 digits (mobile numbers start with 6).</summary>
    [GeneratedRegex(@"^\+237[26]\d{8}$")]
    private static partial Regex CameroonPhone();
}
