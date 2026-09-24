using CocoRider.Domain.Bookings;
using CocoRider.Domain.Common;
using CocoRider.Domain.Trips;

namespace CocoRider.Domain.Reviews;

/// <summary>A rating left after a completed trip, by the passenger about the driver or the other way around.</summary>
public sealed class Review
{
    public const int MaxCommentLength = 1000;

    private Review() { }

    public Guid Id { get; private set; }
    public Guid BookingId { get; private set; }
    public Guid AuthorId { get; private set; }
    public Guid SubjectId { get; private set; }
    public int Rating { get; private set; }
    public string? Comment { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }

    public static Review Write(Booking booking, Trip trip, Guid authorId, int rating, string? comment, DateTimeOffset now)
    {
        if (booking.TripId != trip.Id)
            throw new InvalidOperationException("The booking does not belong to this trip.");
        if (booking.Status is not (BookingStatus.Completed or BookingStatus.NoShow))
            throw new DomainException("review.trip_not_completed", "You can only review a completed trip.");
        if (rating is < 1 or > 5)
            throw new DomainException("review.invalid_rating", "The rating must be between 1 and 5.");
        if (comment is { Length: > MaxCommentLength })
            throw new DomainException("review.comment_too_long", $"The comment cannot exceed {MaxCommentLength} characters.");

        Guid subjectId;
        if (authorId == booking.PassengerId)
        {
            if (booking.Status == BookingStatus.NoShow)
                throw new DomainException("review.no_show", "You did not take part in this trip.");
            subjectId = trip.DriverId;
        }
        else if (authorId == trip.DriverId)
        {
            subjectId = booking.PassengerId;
        }
        else
        {
            throw new ForbiddenException("review.not_participant", "Only the driver and the passenger can review this trip.");
        }

        return new Review
        {
            Id = Guid.NewGuid(),
            BookingId = booking.Id,
            AuthorId = authorId,
            SubjectId = subjectId,
            Rating = rating,
            Comment = string.IsNullOrWhiteSpace(comment) ? null : comment.Trim(),
            CreatedAt = now,
        };
    }
}
