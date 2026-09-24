// Mirrors the JSON contracts of the Coco Rider API (backend/aws-dotnet).
// Enums are sent as PascalCase strings ("NationalId"); Dart uses lowerCamelCase.

T _enum<T extends Enum>(List<T> values, Object? json) {
  final name = (json as String).toLowerCase();
  return values.firstWhere((v) => v.name.toLowerCase() == name);
}

/// The API spelling of a Dart enum value: nationalId → NationalId.
String apiName(Enum value) =>
    value.name[0].toUpperCase() + value.name.substring(1);

DateTime? _date(Object? json) =>
    json == null ? null : DateTime.parse(json as String);

enum Gender { unspecified, female, male }

enum Language { french, english }

enum VerificationStatus { incomplete, manualReview, verified, rejected }

enum DocumentType { nationalId, selfie, driverLicence, insurance, vehicleRegistration }

enum DocumentStatus { awaitingUpload, submitted, accepted, needsReview, rejected }

enum TripKind { intercity, urban }

enum TripStatus { scheduled, cancelled, completed }

enum BookingStatus {
  pending,
  confirmed,
  rejectedByDriver,
  cancelledByPassenger,
  tripCancelled,
  completed,
  noShow,
  expired,
}

enum PaymentMethod { cash, mtnMobileMoney, orangeMoney }

/// Documents whose expiry date the user must type (the API rejects them without it).
bool requiresExpiryDate(DocumentType type) =>
    type == DocumentType.driverLicence || type == DocumentType.insurance;

class RoleVerification {
  final VerificationStatus status;
  final List<DocumentType> required;
  final List<DocumentType> missing;
  final List<DocumentType> expired;

  RoleVerification.fromJson(Map<String, dynamic> json)
      : status = _enum(VerificationStatus.values, json['status']),
        required = _types(json['required']),
        missing = _types(json['missing']),
        expired = _types(json['expired']);

  bool get isVerified => status == VerificationStatus.verified;

  static List<DocumentType> _types(Object? json) =>
      (json as List).map((t) => _enum(DocumentType.values, t)).toList();
}

class Profile {
  final String id;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final Gender gender;
  final Language language;
  final RoleVerification passenger;
  final RoleVerification driver;
  final DateTime? suspendedUntil;

  Profile.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        phoneNumber = json['phoneNumber'],
        firstName = json['firstName'],
        lastName = json['lastName'],
        gender = _enum(Gender.values, json['gender']),
        language = _enum(Language.values, json['language']),
        passenger = RoleVerification.fromJson(json['passenger']),
        driver = RoleVerification.fromJson(json['driver']),
        suspendedUntil = _date(json['suspendedUntil']);

  bool get isSuspended =>
      suspendedUntil != null && suspendedUntil!.isAfter(DateTime.now());
}

class UserDocument {
  final String id;
  final DocumentType type;
  final DocumentStatus status;
  final DateTime? expiresOn;
  final String? reviewNote;

  UserDocument.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        type = _enum(DocumentType.values, json['type']),
        status = _enum(DocumentStatus.values, json['status']),
        expiresOn = _date(json['expiresOn']),
        reviewNote = json['reviewNote'];
}

class UploadSlot {
  final String documentId;
  final Uri uploadUrl;
  final String contentType;

  UploadSlot.fromJson(Map<String, dynamic> json)
      : documentId = json['documentId'],
        uploadUrl = Uri.parse(json['uploadUrl']),
        contentType = json['contentType'];
}

class Vehicle {
  final String id;
  final String make;
  final String model;
  final String color;
  final String plateNumber;
  final int passengerSeats;

  Vehicle.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        make = json['make'],
        model = json['model'],
        color = json['color'],
        plateNumber = json['plateNumber'],
        passengerSeats = json['passengerSeats'];

  String get label => '$make $model · $color · $plateNumber';
}

class Place {
  final String city;
  final String landmark;
  final double latitude;
  final double longitude;

  const Place({
    required this.city,
    required this.landmark,
    required this.latitude,
    required this.longitude,
  });

  Place.fromJson(Map<String, dynamic> json)
      : city = json['city'],
        landmark = json['landmark'],
        latitude = (json['latitude'] as num).toDouble(),
        longitude = (json['longitude'] as num).toDouble();

  Map<String, dynamic> toJson() => {
        'city': city,
        'landmark': landmark,
        'latitude': latitude,
        'longitude': longitude,
      };

  String get label => landmark.isEmpty ? city : '$city · $landmark';
}

class DriverSummary {
  final String id;
  final String firstName;
  final double? rating;
  final int reviewCount;

  DriverSummary.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        firstName = json['firstName'],
        rating = (json['rating'] as num?)?.toDouble(),
        reviewCount = json['reviewCount'];
}

class Trip {
  final String id;
  final TripKind kind;
  final TripStatus status;
  final Place origin;
  final Place destination;
  final DateTime departureAt;
  final int seatsTotal;
  final int seatsAvailable;
  final int pricePerSeatXaf;
  final bool womenOnly;
  final bool luggageAllowed;
  final bool smokingAllowed;
  final bool instantBooking;
  final String? notes;
  final DriverSummary driver;
  final String vehicle;

  Trip.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        kind = _enum(TripKind.values, json['kind']),
        status = _enum(TripStatus.values, json['status']),
        origin = Place.fromJson(json['origin']),
        destination = Place.fromJson(json['destination']),
        departureAt = DateTime.parse(json['departureAt']),
        seatsTotal = json['seatsTotal'],
        seatsAvailable = json['seatsAvailable'],
        pricePerSeatXaf = json['pricePerSeatXaf'],
        womenOnly = json['womenOnly'],
        luggageAllowed = json['luggageAllowed'],
        smokingAllowed = json['smokingAllowed'],
        instantBooking = json['instantBooking'],
        notes = json['notes'],
        driver = DriverSummary.fromJson(json['driver']),
        vehicle = [
          json['vehicle']['make'],
          json['vehicle']['model'],
          json['vehicle']['color'],
        ].join(' ');
}

/// A booking on the driver's trip.
class TripBooking {
  final String id;
  final String passengerId;
  final String passengerFirstName;
  final String? passengerPhone;
  final int seats;
  final BookingStatus status;
  final PaymentMethod paymentMethod;
  final int totalPriceXaf;

  TripBooking.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        passengerId = json['passengerId'],
        passengerFirstName = json['passengerFirstName'],
        passengerPhone = json['passengerPhone'],
        seats = json['seats'],
        status = _enum(BookingStatus.values, json['status']),
        paymentMethod = _enum(PaymentMethod.values, json['paymentMethod']),
        totalPriceXaf = json['totalPriceXaf'];
}

class TripDetails {
  final Trip trip;

  /// Only present when the caller is the driver.
  final List<TripBooking>? bookings;

  TripDetails.fromJson(Map<String, dynamic> json)
      : trip = Trip.fromJson(json['trip']),
        bookings = (json['bookings'] as List?)
            ?.map((b) => TripBooking.fromJson(b))
            .toList();
}

/// A booking as the passenger sees it.
class Booking {
  final String id;
  final BookingStatus status;
  final int seats;
  final PaymentMethod paymentMethod;
  final int totalPriceXaf;
  final Trip trip;
  final String? driverPhone;

  Booking.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        status = _enum(BookingStatus.values, json['status']),
        seats = json['seats'],
        paymentMethod = _enum(PaymentMethod.values, json['paymentMethod']),
        totalPriceXaf = json['totalPriceXaf'],
        trip = Trip.fromJson(json['trip']),
        driverPhone = json['driverPhone'];

  bool get isActive =>
      status == BookingStatus.pending || status == BookingStatus.confirmed;
}
