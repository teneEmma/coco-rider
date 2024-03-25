import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/services/authentication/authentication_response.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'base_authentication.dart';

/// The purpose of this implementation is to fake an auth authentication, and
/// should only be used for testing purposes.
class AuthFakeImplementation implements BaseAuthentication {
  String? _uid;
  final User? _user;
  final String _testPhoneNumber;
  final String _testSmsCode;

  /// Constructs an AuthFakeImplementation.
  AuthFakeImplementation({
    String? uid,
    String? testPhoneNumber,
    String? testSmsCode,
    User? user,
  })  : _uid = uid,
        _user = user,
        _testPhoneNumber =
            testPhoneNumber ?? InternalizationKeys.defaultTestPhoneNumber,
        _testSmsCode = testSmsCode ?? '123456';

  @override
  Future<AuthenticationResponse> authenticateWithPhoneNumber(
    PhoneNumberAuthenticationParameter param,
  ) async {
    if (param.phoneNumber == _testPhoneNumber) {
      param.onVerificationCodeSent();

      return AuthenticationResponse.verificationSuccessful;
    }

    return AuthenticationResponse.verificationFailed;
  }

  @override
  Future<AuthenticationResponse> authenticateWithOTPCode(
    String phoneNumber,
    String otpCode, {
    required Function onVerificationCompleted,
    required Function(String) onVerificationFailed,
  }) async {
    if (otpCode == _testSmsCode) {
      onVerificationCompleted();

      return AuthenticationResponse.verificationSuccessful;
    }
    onVerificationFailed('otp-code-does-not-match');

    return AuthenticationResponse.verificationFailed;
  }

  @override
  Future<void> signOut() async {
    _uid = null;
  }

  @override
  String? get uid => _uid;

  @override
  User? get user => _user;
}
