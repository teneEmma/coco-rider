// Mirrors the C# contracts in backend/aws-dotnet/src/CocoRider.Api/Features/Admin.

export type DocumentType = 'NationalId' | 'Selfie' | 'DriverLicence' | 'Insurance' | 'VehicleRegistration';
export type DocumentStatus = 'AwaitingUpload' | 'Submitted' | 'Accepted' | 'NeedsReview' | 'Rejected';
export type VerificationStatus = 'Incomplete' | 'ManualReview' | 'Verified' | 'Rejected';

export interface Stats {
  users: number;
  verifiedDrivers: number;
  verifiedPassengers: number;
  documentsToReview: number;
  upcomingTrips: number;
  bookingsLast30Days: number;
  commissionOwedLast30DaysXaf: number;
}

export interface ReviewQueueItem {
  documentId: string;
  userId: string;
  userName: string;
  phoneNumber: string;
  type: DocumentType;
  status: DocumentStatus;
  expiresOn: string | null;
  reviewNote: string | null;
  imageUrl: string;
  submittedAt: string;
}

export interface AdminUser {
  id: string;
  phoneNumber: string;
  firstName: string;
  lastName: string;
  passengerStatus: VerificationStatus;
  driverStatus: VerificationStatus;
  strikes: number;
  suspendedUntil: string | null;
  suspensionReason: string | null;
  createdAt: string;
}
