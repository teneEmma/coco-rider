import 'package:coco_rider/services/authentication/auth_cognito_implementation.dart';
import 'package:coco_rider/services/authentication/auth_development_implementation.dart';
import 'package:coco_rider/services/authentication/auth_fake_implementation.dart';

import 'authentication_response.dart';

/// The signed-in user, independent of the authentication provider.
class AuthUser {
  /// Provider user id (Cognito "sub").
  final String uid;

  /// E.164 phone number, e.g. +237690000000. Empty for users who signed in by email.
  final String phoneNumber;

  /// Email address, for users who signed in by email.
  final String? email;

  const AuthUser({required this.uid, required this.phoneNumber, this.email});

  /// True when the user signed in by email: their profile must ask for a phone number.
  bool get signedInWithEmail => phoneNumber.isEmpty && email != null;
}

/// Service that provides Authentication implementation to the app.
abstract class BaseAuthentication {
  /// Returns the user unique identifier.
  String? get uid => user?.uid;

  /// Returns the actual user info.
  AuthUser? get user;

  /// Constructs the Authentication using an Auth type.
  factory BaseAuthentication(AuthType authType) {
    return switch (authType) {
      AuthType.cognito => AuthCognitoImplementation(),
      AuthType.development => AuthDevelopmentImplementation(),
      AuthType.fake => AuthFakeImplementation(),
    };
  }

  /// Constructs the Authentication service using a fake implementation with
  /// a custom configuration.
  factory BaseAuthentication.fake({
    String? uid,
    String? testPhoneNumber,
    String? testSmsCode,
    AuthUser? user,
  }) =>
      AuthFakeImplementation(
        uid: uid,
        testPhoneNumber: testPhoneNumber,
        testSmsCode: testSmsCode,
        user: user,
      );

  /// Restores the session saved on the device, if any. Returns true when signed in.
  Future<bool> restoreSession();

  /// Headers that authenticate a call to the Coco Rider API.
  Future<Map<String, String>> authHeaders();

  /// Signs out a user.
  Future<void> signOut();

  /// Attempts to authenticate and verify a user using their phone number.
  ///
  /// [verificationSuccessful] Response sent when the SMS code was sent.
  ///
  /// [verificationFailed] Response sent when the code could not be sent.
  Future<AuthenticationResponse> authenticateWithPhoneNumber(
    PhoneNumberAuthenticationParameter param,
  );

  /// Sends a one-time code to an email address (sign-in, or sign-up for a new address).
  Future<AuthenticationResponse> authenticateWithEmail(
    EmailAuthenticationParameter param,
  );

  /// Attempts to verify the authenticity of the OTP code which has been
  /// sent to a user. [phoneNumber] is the phone number or the email address
  /// the code was sent to.
  ///
  /// [verificationSuccessful] Response sent when the OTP code is correct.
  ///
  /// [verificationFailed] Response sent when the OTP code is incorrect.
  Future<AuthenticationResponse> authenticateWithOTPCode(
    String phoneNumber,
    String otpCode, {
    required Function onVerificationCompleted,
    required Function(String) onVerificationFailed,
  });
}

/// The parameter to provide for phone number authentication.
class PhoneNumberAuthenticationParameter {
  /// The phone number for authentication.
  final String phoneNumber;

  /// The method to call on verification completed.
  final Function onVerificationCompleted;

  /// The method to call on verification failed.
  final Function(String) onVerificationFailed;

  /// The method to call on verification code sent.
  final Function onVerificationCodeSent;

  /// The method to call on verification auto retrieval timeout.
  final Function onVerificationAutoRetrievalTimeout;

  /// Constructs a new [PhoneNumberAuthenticationParameter].
  PhoneNumberAuthenticationParameter({
    required this.phoneNumber,
    required this.onVerificationCompleted,
    required this.onVerificationFailed,
    required this.onVerificationCodeSent,
    required this.onVerificationAutoRetrievalTimeout,
  });
}

/// The parameter to provide for email authentication.
class EmailAuthenticationParameter {
  final String email;
  final Function onVerificationCodeSent;
  final Function(String) onVerificationFailed;

  EmailAuthenticationParameter({
    required this.email,
    required this.onVerificationCodeSent,
    required this.onVerificationFailed,
  });
}

/// Supported authentication backend types.
enum AuthType {
  /// Amazon Cognito: phone number + SMS code, or email + emailed code (production).
  cognito,

  /// Local API in development mode: no SMS or email, the code is always 123456.
  development,

  /// Fake auth implementation for testing.
  fake,
}
