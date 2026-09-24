namespace CocoRider.Domain.Users;

public enum Language
{
    French,
    English,
}

public enum Gender
{
    Unspecified,
    Female,
    Male,
}

/// <summary>A user is verified separately as a passenger and as a driver.</summary>
public enum VerificationRole
{
    Passenger,
    Driver,
}

public enum VerificationStatus
{
    /// <summary>At least one required document has not been submitted yet.</summary>
    Incomplete,

    /// <summary>All documents are submitted and at least one waits for an admin.</summary>
    ManualReview,

    Verified,

    /// <summary>At least one required document was rejected and must be re-submitted.</summary>
    Rejected,
}
