using CocoRider.Domain.Bookings;
using CocoRider.Domain.Trips;

namespace CocoRider.Api.Features.Trips;

public sealed record LocationDto(string City, string Landmark, double Latitude, double Longitude)
{
    public static LocationDto From(TripLocation l) => new(l.City, l.Landmark, l.Latitude, l.Longitude);

    public TripLocation ToDomain() => new(City, Landmark, Latitude, Longitude);
}

public sealed record PublishTripRequest(
    Guid VehicleId,
    TripKind Kind,
    LocationDto Origin,
    LocationDto Destination,
    DateTimeOffset DepartureAt,
    int Seats,
    long PricePerSeatXaf,
    bool LuggageAllowed,
    bool SmokingAllowed,
    bool InstantBooking,
    string? Notes);

public sealed record DriverSummary(Guid Id, string FirstName, double? Rating, int ReviewCount);

public sealed record VehicleSummary(string Make, string Model, string Color);

public sealed record TripResponse(
    Guid Id,
    TripKind Kind,
    TripStatus Status,
    LocationDto Origin,
    LocationDto Destination,
    DateTimeOffset DepartureAt,
    int SeatsTotal,
    int SeatsAvailable,
    long PricePerSeatXaf,
    bool LuggageAllowed,
    bool SmokingAllowed,
    bool InstantBooking,
    string? Notes,
    DriverSummary Driver,
    VehicleSummary Vehicle);

/// <summary>A booking as the driver sees it. The phone number is shown once the booking is confirmed.</summary>
public sealed record TripBookingResponse(Guid Id, Guid PassengerId, string PassengerFirstName, string? PassengerPhone,
    int Seats, BookingStatus Status, PaymentMethod PaymentMethod, long TotalPriceXaf);

public sealed record TripDetailsResponse(TripResponse Trip, IReadOnlyList<TripBookingResponse>? Bookings);
