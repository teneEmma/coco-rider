import 'package:coco_rider/services/authentication/auth_fake_implementation.dart';
import 'package:coco_rider/services/authentication/auth_firebase_implementation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'authentication_response.dart';

/// Service that provides Authentication implementation to the app.
abstract class BaseAuthentication {
  /// Returns the user unique identifier.
  String? get uid;

  /// Returns the actual user info.
  User? get user;

  /// Constructs the Authentication using an Auth type.
  factory BaseAuthentication(AuthType authType) {
    return switch (authType) {
      AuthType.fake => AuthFakeImplementation(),
      _ => AuthFirebaseImplementation(),
    };
  }

  /// Constructs the Authentication service using a fake implementation with
  /// a custom configuration.
  factory BaseAuthentication.fake({
    String? uid,
    String? testPhoneNumber,
    String? testSmsCode,
    User? user,
  }) =>
      AuthFakeImplementation(
        uid: uid,
        testPhoneNumber: testPhoneNumber,
        testSmsCode: testSmsCode,
        user: user,
      );

  /// Signs out a user.
  Future<void> signOut();

  /// Attempts to authenticate and verify a user using their phone number.
  ///
  /// [verificationSuccessful] Response sent when phone verification was successful.
  ///
  /// [verificationFailed] Response sent when phone verification failed.
  Future<AuthenticationResponse> authenticateWithPhoneNumber(
    PhoneNumberAuthenticationParameter param,
  );

  /// Attempts to verify the authenticity of the OTP code which has been
  /// sent to a user.
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

/// Supported authentication backend types.
enum AuthType {
  /// Firebase implementation for Auth.
  firebase,

  /// Fake auth implementation for testing.
  fake,
}
