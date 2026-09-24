using CocoRider.Domain.Common;

namespace CocoRider.Domain.Users;

public sealed class User
{
    private readonly List<Strike> _strikes = [];

    private User() { }

    public User(string cognitoSub, string phoneNumber, string firstName, string lastName, Gender gender, Language language, DateTimeOffset now)
    {
        Id = Guid.NewGuid();
        CognitoSub = cognitoSub;
        PhoneNumber = phoneNumber;
        CreatedAt = now;
        UpdateProfile(firstName, lastName, gender, language);
    }

    public Guid Id { get; private set; }

    /// <summary>The Cognito "sub" claim; links the token to this profile.</summary>
    public string CognitoSub { get; private set; } = null!;

    /// <summary>E.164 phone number, e.g. +2376XXXXXXXX.</summary>
    public string PhoneNumber { get; private set; } = null!;

    public string FirstName { get; private set; } = null!;
    public string LastName { get; private set; } = null!;
    public Gender Gender { get; private set; }
    public Language Language { get; private set; }

    public VerificationStatus PassengerStatus { get; private set; } = VerificationStatus.Incomplete;
    public VerificationStatus DriverStatus { get; private set; } = VerificationStatus.Incomplete;

    public DateTimeOffset? SuspendedUntil { get; private set; }
    public string? SuspensionReason { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public IReadOnlyCollection<Strike> Strikes => _strikes;

    public bool IsSuspended(DateTimeOffset now) => SuspendedUntil is { } until && until > now;

    public void UpdateProfile(string firstName, string lastName, Gender gender, Language language)
    {
        if (string.IsNullOrWhiteSpace(firstName) || string.IsNullOrWhiteSpace(lastName))
            throw new DomainException("profile.name_required", "First name and last name are required.");

        FirstName = firstName.Trim();
        LastName = lastName.Trim();
        Gender = gender;
        Language = language;
    }

    public void SetVerificationStatus(VerificationRole role, VerificationStatus status)
    {
        if (role == VerificationRole.Driver)
            DriverStatus = status;
        else
            PassengerStatus = status;
    }

    public void EnsureCanTravel(DateTimeOffset now)
    {
        EnsureNotSuspended(now);
        if (PassengerStatus != VerificationStatus.Verified)
            throw new DomainException("verification.passenger_not_verified", "Your documents must be verified before you can book a trip.");
    }

    public void EnsureCanDrive(DateTimeOffset now)
    {
        EnsureNotSuspended(now);
        if (DriverStatus != VerificationStatus.Verified)
            throw new DomainException("verification.driver_not_verified", "Your driver documents must be verified before you can publish a trip.");
    }

    /// <summary>Records a strike and suspends the user when the policy threshold is reached.</summary>
    public Strike AddStrike(StrikeReason reason, Guid? bookingId, DateTimeOffset now, PlatformPolicy policy)
    {
        var strike = new Strike(Id, reason, bookingId, now);
        _strikes.Add(strike);

        var windowStart = now.AddDays(-policy.StrikeWindowDays);
        var recent = _strikes.Count(s => s.CreatedAt >= windowStart);
        if (recent >= policy.MaxStrikes)
            Suspend(now.AddDays(policy.SuspensionDays), $"{recent} strikes in {policy.StrikeWindowDays} days");

        return strike;
    }

    public void Suspend(DateTimeOffset until, string reason)
    {
        SuspendedUntil = until;
        SuspensionReason = reason;
    }

    public void LiftSuspension()
    {
        SuspendedUntil = null;
        SuspensionReason = null;
    }

    private void EnsureNotSuspended(DateTimeOffset now)
    {
        if (IsSuspended(now))
            throw new DomainException("account.suspended", "Your account is suspended.");
    }
}
