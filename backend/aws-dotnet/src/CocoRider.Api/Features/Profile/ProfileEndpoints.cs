using System.Text.RegularExpressions;
using CocoRider.Api.Auth;
using CocoRider.Api.Features.Documents;
using CocoRider.Domain.Common;
using CocoRider.Domain.Users;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Api.Features.Profile;

/// <param name="PhoneNumber">
/// Only for users who signed in by email (their token has no verified phone): the number other
/// users call once a booking is confirmed. Ignored for users who signed in with an SMS code.
/// </param>
public sealed record UpsertProfileRequest(string FirstName, string LastName, Language Language, string? PhoneNumber = null);

public sealed record ProfileResponse(
    Guid Id,
    string PhoneNumber,
    bool PhoneVerified,
    string? Email,
    string FirstName,
    string LastName,
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

    /// <summary>Creates the profile on first call (right after sign-up), then updates it.</summary>
    private static async Task<ProfileResponse> UpsertAsync(UpsertProfileRequest request, CurrentUser current,
        CocoRiderDbContext db, VerificationService verification, TimeProvider clock, CancellationToken ct)
    {
        var user = await current.FindProfileAsync(ct);
        if (user is null)
        {
            // SMS sign-in: the number comes from the token. Email sign-in: the user types it.
            var verifiedPhone = current.PhoneNumber;
            if (verifiedPhone is null && current.Email is null)
                throw new DomainException("profile.invalid_phone", "A verified phone number or email address is required.");
            var phone = verifiedPhone ?? NormalizePhone(request.PhoneNumber);
            if (phone is null || !CameroonPhone().IsMatch(phone))
                throw new DomainException("profile.invalid_phone", "A Cameroonian phone number (+237) is required.");
            await EnsurePhoneFreeAsync(db, phone, null, ct);

            user = new User(current.Sub, phone, request.FirstName, request.LastName, request.Language,
                clock.GetUtcNow(), current.Email, phoneVerified: verifiedPhone is not null);
            db.Users.Add(user);
        }
        else
        {
            user.UpdateProfile(request.FirstName, request.LastName, request.Language);
            if (!user.PhoneVerified && NormalizePhone(request.PhoneNumber) is { } phone && phone != user.PhoneNumber)
            {
                if (!CameroonPhone().IsMatch(phone))
                    throw new DomainException("profile.invalid_phone", "A Cameroonian phone number (+237) is required.");
                await EnsurePhoneFreeAsync(db, phone, user.Id, ct);
                user.ChangeUnverifiedPhone(phone);
            }
            if (current.Email is { } email && email != user.Email)
                user.SetEmail(email);
        }

        var response = await ToResponseAsync(user, verification, ct);
        await db.SaveChangesAsync(ct);
        return response;
    }

    internal static async Task<ProfileResponse> ToResponseAsync(User user, VerificationService verification, CancellationToken ct)
    {
        var roles = await verification.RefreshAsync(user, ct);
        return new ProfileResponse(user.Id, user.PhoneNumber, user.PhoneVerified, user.Email, user.FirstName, user.LastName, user.Language,
            roles[VerificationRole.Passenger], roles[VerificationRole.Driver], user.SuspendedUntil, user.CreatedAt);
    }

    private static async Task EnsurePhoneFreeAsync(CocoRiderDbContext db, string phone, Guid? exceptUserId, CancellationToken ct)
    {
        if (await db.Users.AnyAsync(u => u.PhoneNumber == phone && u.Id != exceptUserId, ct))
            throw new DomainException("profile.phone_taken", "This phone number is already used by another account.");
    }

    /// <summary>"6 90 00 00 01" or "690000001" → "+237690000001".</summary>
    private static string? NormalizePhone(string? phone)
    {
        if (string.IsNullOrWhiteSpace(phone))
            return null;
        var digits = new string(phone.Where(c => char.IsDigit(c)).ToArray());
        return digits.Length == 9 ? $"+237{digits}" : $"+{digits}";
    }

    /// <summary>Cameroonian numbers: +237 followed by 9 digits (mobile numbers start with 6).</summary>
    [GeneratedRegex(@"^\+237[26]\d{8}$")]
    private static partial Regex CameroonPhone();
}
