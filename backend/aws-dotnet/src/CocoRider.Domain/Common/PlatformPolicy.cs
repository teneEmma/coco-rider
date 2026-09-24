namespace CocoRider.Domain.Common;

/// <summary>
/// Business rules that the operations team is expected to tune without code changes.
/// Bound from the "Policy" configuration section.
/// </summary>
public sealed class PlatformPolicy
{
    /// <summary>Bookings can be cancelled for free until this many hours before departure; after that they cannot be cancelled.</summary>
    public int CancellationWindowHours { get; set; } = 24;

    /// <summary>Commission taken per booking, in basis points (100 = 1%). 0 while the platform is free.</summary>
    public int CommissionRateBasisPoints { get; set; } = 0;

    /// <summary>Number of strikes within <see cref="StrikeWindowDays"/> that triggers a suspension.</summary>
    public int MaxStrikes { get; set; } = 3;

    public int StrikeWindowDays { get; set; } = 90;

    public int SuspensionDays { get; set; } = 30;

    /// <summary>Trips must be published at least this many minutes before departure.</summary>
    public int MinimumMinutesBeforeDeparture { get; set; } = 30;

    /// <summary>Minimum face similarity (0-100) between the selfie and the national ID card for automatic approval.</summary>
    public float FaceMatchThreshold { get; set; } = 90f;

    public TimeSpan CancellationWindow => TimeSpan.FromHours(CancellationWindowHours);

    public long CommissionFor(long amountXaf) =>
        (long)Math.Round(amountXaf * CommissionRateBasisPoints / 10_000m, MidpointRounding.AwayFromZero);
}
