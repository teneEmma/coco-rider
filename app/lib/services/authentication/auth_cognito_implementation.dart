import 'dart:convert';

import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/services/authentication/authentication_response.dart';
import 'package:coco_rider/services/authentication/base_authentication.dart';
import 'package:coco_rider/services/authentication/cognito_client.dart';
import 'package:coco_rider/services/authentication/token_store.dart';
import 'package:coco_rider/services/config/app_config.dart';

/// Sign-in with a phone number and an SMS code through Amazon Cognito.
class AuthCognitoImplementation implements BaseAuthentication {
  final CognitoClient _cognito;
  final TokenStore _store;
  final Map<String, PendingCode> _pendingCodes = {};
  CognitoTokens? _tokens;

  AuthCognitoImplementation({CognitoClient? cognito, TokenStore? store})
      : _cognito = cognito ??
            CognitoClient(
              region: AppConfig.cognitoRegion,
              clientId: AppConfig.cognitoClientId,
            ),
        _store = store ?? TokenStore.secure();

  @override
  AuthUser? get user {
    final tokens = _tokens;
    if (tokens == null) return null;
    final claims = tokens.claims;
    return AuthUser(
      uid: claims['sub'] as String,
      phoneNumber: claims['phone_number'] as String? ?? '',
    );
  }

  @override
  String? get uid => user?.uid;

  @override
  Future<bool> restoreSession() async {
    final saved = await _store.read();
    if (saved == null) return false;
    try {
      _tokens = CognitoTokens.fromJson(jsonDecode(saved));
      return true;
    } catch (_) {
      await _store.delete();
      return false;
    }
  }

  @override
  Future<Map<String, String>> authHeaders() async {
    var tokens = _tokens;
    if (tokens == null) return {};
    if (tokens.isExpiringSoon) {
      try {
        tokens = await _cognito.refresh(tokens.refreshToken);
        await _save(tokens);
      } on CognitoException catch (e) {
        UtilityFunctions.debugPrint('Token refresh failed: $e', leadingIcons: '🔐');
        await signOut();
        return {};
      }
    }
    return {'Authorization': 'Bearer ${tokens.idToken}'};
  }

  @override
  Future<AuthenticationResponse> authenticateWithPhoneNumber(
    PhoneNumberAuthenticationParameter param,
  ) async {
    try {
      _pendingCodes[param.phoneNumber] = await _cognito.sendCode(param.phoneNumber);
      param.onVerificationCodeSent();
      return AuthenticationResponse.verificationSuccessful;
    } on CognitoException catch (e) {
      UtilityFunctions.debugPrint('Sending the code failed: $e', leadingIcons: '😓');
      param.onVerificationFailed(e.type);
      return AuthenticationResponse.verificationFailed;
    } catch (e) {
      param.onVerificationFailed('network-request-failed');
      return AuthenticationResponse.verificationFailed;
    }
  }

  @override
  Future<AuthenticationResponse> authenticateWithOTPCode(
    String phoneNumber,
    String otpCode, {
    required Function onVerificationCompleted,
    required Function(String) onVerificationFailed,
  }) async {
    final pending = _pendingCodes[phoneNumber];
    if (pending == null) {
      onVerificationFailed('code-not-requested');
      return AuthenticationResponse.verificationFailed;
    }
    try {
      await _save(await _cognito.confirmCode(phoneNumber, pending, otpCode));
      _pendingCodes.remove(phoneNumber);
      onVerificationCompleted();
      return AuthenticationResponse.verificationSuccessful;
    } on CognitoException catch (e) {
      onVerificationFailed(e.type);
      return AuthenticationResponse.verificationFailed;
    } catch (e) {
      onVerificationFailed('network-request-failed');
      return AuthenticationResponse.verificationFailed;
    }
  }

  @override
  Future<void> signOut() async {
    _tokens = null;
    await _store.delete();
  }

  Future<void> _save(CognitoTokens tokens) async {
    _tokens = tokens;
    await _store.write(jsonEncode(tokens.toJson()));
  }
}
