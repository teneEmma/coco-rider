namespace CocoRider.Domain.Common;

/// <summary>
/// A business rule was violated. <see cref="Code"/> is a stable, machine readable
/// identifier that the mobile app and admin dashboard translate (FR/EN).
/// </summary>
public class DomainException(string code, string message) : Exception(message)
{
    public string Code { get; } = code;
}

/// <summary>The caller is not allowed to act on this resource.</summary>
public sealed class ForbiddenException(string code, string message) : DomainException(code, message);

/// <summary>The requested resource does not exist (or is not visible to the caller).</summary>
public sealed class NotFoundException(string code, string message) : DomainException(code, message);
