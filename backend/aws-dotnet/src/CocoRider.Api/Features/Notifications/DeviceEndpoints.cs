using CocoRider.Api.Auth;
using CocoRider.Domain.Common;
using CocoRider.Domain.Notifications;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Api.Features.Notifications;

public sealed record RegisterDeviceRequest(string Token, DevicePlatform Platform);

/// <summary>The app registers its Firebase token after sign-in and whenever it changes.</summary>
public static class DeviceEndpoints
{
    public static void MapDeviceEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/v1/me/devices").WithTags("Notifications");
        group.MapPut("/", RegisterAsync);
        group.MapDelete("/{token}", UnregisterAsync);
    }

    private static async Task<IResult> RegisterAsync(RegisterDeviceRequest request, CurrentUser current, CocoRiderDbContext db,
        TimeProvider clock, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Token) || request.Token.Length > 512)
            throw new DomainException("device.invalid_token", "The device token is invalid.");

        var user = await current.RequireProfileAsync(ct);
        var now = clock.GetUtcNow();
        var existing = await db.DeviceTokens.FirstOrDefaultAsync(d => d.Token == request.Token, ct);
        if (existing is null)
            db.DeviceTokens.Add(new DeviceToken(user.Id, request.Token, request.Platform, now));
        else
            existing.Assign(user.Id, request.Platform, now);

        await db.SaveChangesAsync(ct);
        return Results.NoContent();
    }

    /// <summary>Called on sign-out so the phone stops receiving this account's notifications.</summary>
    private static async Task<IResult> UnregisterAsync(string token, CurrentUser current, CocoRiderDbContext db, CancellationToken ct)
    {
        var user = await current.RequireProfileAsync(ct);
        await db.DeviceTokens.Where(d => d.Token == token && d.UserId == user.Id).ExecuteDeleteAsync(ct);
        return Results.NoContent();
    }
}
