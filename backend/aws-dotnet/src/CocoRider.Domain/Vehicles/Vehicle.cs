using CocoRider.Domain.Common;

namespace CocoRider.Domain.Vehicles;

public sealed class Vehicle
{
    public const int MaxPassengerSeats = 8;

    private Vehicle() { }

    public Vehicle(Guid ownerId, string make, string model, string color, string plateNumber, int passengerSeats)
    {
        if (string.IsNullOrWhiteSpace(make) || string.IsNullOrWhiteSpace(model))
            throw new DomainException("vehicle.make_model_required", "Make and model are required.");
        if (string.IsNullOrWhiteSpace(plateNumber))
            throw new DomainException("vehicle.plate_required", "The plate number is required.");
        if (passengerSeats is < 1 or > MaxPassengerSeats)
            throw new DomainException("vehicle.invalid_seats", $"A vehicle must offer between 1 and {MaxPassengerSeats} passenger seats.");

        Id = Guid.NewGuid();
        OwnerId = ownerId;
        Make = make.Trim();
        Model = model.Trim();
        Color = color.Trim();
        PlateNumber = NormalizePlate(plateNumber);
        PassengerSeats = passengerSeats;
    }

    public Guid Id { get; private set; }
    public Guid OwnerId { get; private set; }
    public string Make { get; private set; } = null!;
    public string Model { get; private set; } = null!;
    public string Color { get; private set; } = null!;

    /// <summary>Upper-case plate without spaces or dashes, e.g. "LT123AB".</summary>
    public string PlateNumber { get; private set; } = null!;

    /// <summary>Seats available to passengers (driver seat excluded).</summary>
    public int PassengerSeats { get; private set; }

    public bool IsArchived { get; private set; }

    public void Archive() => IsArchived = true;

    public static string NormalizePlate(string plate) =>
        new(plate.Where(char.IsLetterOrDigit).Select(char.ToUpperInvariant).ToArray());
}
