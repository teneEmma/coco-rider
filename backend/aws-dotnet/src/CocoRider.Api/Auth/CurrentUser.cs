using CocoRider.Domain.Common;
using CocoRider.Domain.Users;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Api.Auth;

/// <summary>The authenticated caller, resolved from the token's "sub" claim.</summary>
public sealed class CurrentUser(IHttpContextAccessor accessor, CocoRiderDbContext db)
{
    private HttpContext Context => accessor.HttpContext ?? throw new InvalidOperationException("No HTTP request.");

    public string Sub => Context.User.FindFirst(Claims.Subject)?.Value
        ?? throw new InvalidOperationException("The token has no subject.");

    /// <summary>
    /// The phone number, only once Cognito has verified it by SMS. An email user could add an
    /// unverified number to their Cognito account; it must not count as verified here.
    /// </summary>
    public string? PhoneNumber => Context.User.FindFirst(Claims.PhoneVerified)?.Value == "true"
        ? Context.User.FindFirst(Claims.Phone)?.Value
        : null;

    /// <summary>The email address, only once Cognito has verified it (email sign-in).</summary>
    public string? Email => Context.User.FindFirst(Claims.EmailVerified)?.Value == "true"
        ? Context.User.FindFirst(Claims.Email)?.Value
        : null;

    public bool IsAdmin => Context.User.HasClaim(Claims.Groups, Claims.AdminGroup);

    public Task<User?> FindProfileAsync(CancellationToken ct) =>
        db.Users.Include(u => u.Strikes).FirstOrDefaultAsync(u => u.CognitoSub == Sub, ct);

    /// <summary>The caller's profile; the app must create it (PUT /v1/me) right after sign-up.</summary>
    public async Task<User> RequireProfileAsync(CancellationToken ct) =>
        await FindProfileAsync(ct)
            ?? throw new NotFoundException("profile.not_found", "Create your profile first.");
}
