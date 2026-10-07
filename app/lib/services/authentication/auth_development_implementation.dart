import 'package:coco_rider/services/authentication/authentication_response.dart';
import 'package:coco_rider/services/authentication/base_authentication.dart';
import 'package:coco_rider/services/authentication/token_store.dart';

/// For a local API running in development mode: no SMS or email is sent, any phone
/// number or email address works with the code [developmentCode], and the API trusts
/// the X-Dev-* headers.
class AuthDevelopmentImplementation implements BaseAuthentication {
  static const developmentCode = '123456';

  final TokenStore _store;
  AuthUser? _user;

  AuthDevelopmentImplementation({TokenStore? store})
      : _store = store ?? TokenStore.secure();

  @override
  AuthUser? get user => _user;

  @override
  String? get uid => _user?.uid;

  @override
  Future<bool> restoreSession() async {
    final identifier = await _store.read();
    if (identifier == null) return false;
    _user = _userFor(identifier);
    return true;
  }

  @override
  Future<Map<String, String>> authHeaders() async {
    final user = _user;
    if (user == null) return {};
    return {
      'X-Dev-User': user.uid,
      if (user.phoneNumber.isNotEmpty) 'X-Dev-Phone': user.phoneNumber,
      if (user.email != null) 'X-Dev-Email': user.email!,
    };
  }

  @override
  Future<AuthenticationResponse> authenticateWithPhoneNumber(
    PhoneNumberAuthenticationParameter param,
  ) async {
    param.onVerificationCodeSent();
    return AuthenticationResponse.verificationSuccessful;
  }

  @override
  Future<AuthenticationResponse> authenticateWithEmail(
    EmailAuthenticationParameter param,
  ) async {
    param.onVerificationCodeSent();
    return AuthenticationResponse.verificationSuccessful;
  }

  @override
  Future<AuthenticationResponse> authenticateWithOTPCode(
    String phoneNumber,
    String otpCode, {
    required Function onVerificationCompleted,
    required Function(String) onVerificationFailed,
  }) async {
    if (otpCode != developmentCode) {
      onVerificationFailed('CodeMismatchException');
      return AuthenticationResponse.verificationFailed;
    }
    _user = _userFor(phoneNumber);
    await _store.write(phoneNumber);
    onVerificationCompleted();
    return AuthenticationResponse.verificationSuccessful;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    await _store.delete();
  }

  /// [identifier] is a phone number (+237…) or an email address.
  static AuthUser _userFor(String identifier) {
    if (identifier.contains('@')) {
      final email = identifier.trim().toLowerCase();
      return AuthUser(uid: 'dev-$email', phoneNumber: '', email: email);
    }
    return AuthUser(uid: 'dev-${identifier.replaceAll('+', '')}', phoneNumber: identifier);
  }
}
