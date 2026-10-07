import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/services/authentication/authentication_response.dart';
import 'package:coco_rider/services/authentication/base_authentication.dart';
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
    AuthUser? user,
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

  /// The signed-in user (phone number or email), or null.
  AuthUser? get user => _baseAuthentication.user;

  /// Checks if the user is logged in.
  RxBool get userIsLogged => (_baseAuthentication.user != null).obs;

  /// Restores the session saved on the device. Returns true when signed in.
  Future<bool> restoreSession() => _baseAuthentication.restoreSession();

  /// Headers that authenticate a call to the Coco Rider API.
  Future<Map<String, String>> authHeaders() => _baseAuthentication.authHeaders();

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

  /// Sends a one-time code by email.
  Future<AuthenticationResponse> authenticateWithEmail(
    EmailAuthenticationParameter param,
  ) {
    UtilityFunctions.debugPrint('Email authentication started.',
        leadingIcons: '🔐🔐🔐');
    return _baseAuthentication.authenticateWithEmail(param);
  }

  /// Attempts to authenticate and verify a user using their phone number (or
  /// email address) and an OTP code.
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
