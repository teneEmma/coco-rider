using CocoRider.Domain.Common;
using NetTopologySuite.Geometries;

namespace CocoRider.Domain.Trips;

/// <summary>
/// A pickup or drop-off point. Addresses in Cameroon are mostly informal, so the
/// <see cref="Landmark"/> ("Carrefour Ndokoti", "Total Mvan") matters as much as the GPS pin.
/// </summary>
public sealed class TripLocation
{
    /// <summary>WGS 84, the coordinate system of phone GPS and every map SDK.</summary>
    public const int Srid = 4326;

    private TripLocation() { }

    public TripLocation(string city, string landmark, double latitude, double longitude)
    {
        if (string.IsNullOrWhiteSpace(city))
            throw new DomainException("location.city_required", "The city is required.");
        if (latitude is < -90 or > 90 || longitude is < -180 or > 180)
            throw new DomainException("location.invalid_coordinates", "The coordinates are invalid.");

        City = city.Trim();
        Landmark = landmark.Trim();
        Point = CreatePoint(latitude, longitude);
    }

    public string City { get; private set; } = null!;
    public string Landmark { get; private set; } = null!;

    /// <summary>X = longitude, Y = latitude.</summary>
    public Point Point { get; private set; } = null!;

    public double Latitude => Point.Y;
    public double Longitude => Point.X;

    public static Point CreatePoint(double latitude, double longitude) =>
        new(longitude, latitude) { SRID = Srid };
}
