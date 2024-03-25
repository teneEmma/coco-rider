import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/services/authentication/authentication_response.dart';
import 'package:coco_rider/services/authentication/base_authentication.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// The auth class which encompasses and handles everything related with
/// authentication in and out the app.
class Auth extends GetxController {
  final BaseAuthentication _baseAuthentication;

  /// Constructs the Authentication using an Auth type.
  factory Auth(
    AuthType authType,
  ) =>
      Auth._(BaseAuthentication(authType));

  /// Constructs the auth object.
  Auth._(this._baseAuthentication);

  /// Constructs the Authentication service using a fake implementation.
  factory Auth.fake({
    String? uid,
    String? testPhoneNumber,
    String? testSmsCode,
    User? user,
  }) =>
      Auth._(
        BaseAuthentication.fake(
          uid: uid,
          testPhoneNumber: testPhoneNumber,
          testSmsCode: testSmsCode,
          user: user,
        ),
      );

  /// Returns the user's phone number.
  Rx<String?>? get userPhoneNumber => _baseAuthentication.user?.phoneNumber.obs;

  /// Returns the user's first name.
  Rx<String?>? get userFirstName => _baseAuthentication.user?.displayName.obs;

  /// Checks if the user is logged in.
  RxBool get userIsLogged => (_baseAuthentication.user != null).obs;

  /// Returns the User Id.
  Rx<String?> get userId => _baseAuthentication.uid.obs;

  /// Logs-out a user.
  Future<void> logout() async {
    UtilityFunctions.debugPrint('Log-out started.', leadingIcons: '📤📤📤');
    await _baseAuthentication.signOut();
  }

  /// Attempts to authenticate a user.
  Future<AuthenticationResponse> authenticateWithPhoneNumber(
    PhoneNumberAuthenticationParameter param,
  ) async {
    UtilityFunctions.debugPrint('Phone number authentication started.',
        leadingIcons: '🔐🔐🔐');

    return _baseAuthentication.authenticateWithPhoneNumber(param);
  }

  /// Attempts to authenticate and verify a user using their phone number and
  /// an OTP code.
  Future<AuthenticationResponse> authenticateWithOTPCode(
    String phoneNumber,
    String otpCode, {
    required Function onVerificationCompleted,
    required void Function(String) onVerificationFailed,
  }) async {
    UtilityFunctions.debugPrint('OTP authentication started.',
        leadingIcons: '🔓🔓🔓');

    return _baseAuthentication.authenticateWithOTPCode(
      phoneNumber,
      otpCode,
      onVerificationCompleted: onVerificationCompleted,
      onVerificationFailed: onVerificationFailed,
    );
  }
}
