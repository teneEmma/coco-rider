import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/services/authentication/authentication_response.dart';
import 'package:coco_rider/services/authentication/base_authentication.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthFirebaseImplementation implements BaseAuthentication {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final Map<String, String> _otpVerificationIds = {};
  final Map<String, int?> _resendTokens = {};

  @override
  Future<AuthenticationResponse> authenticateWithPhoneNumber(
    PhoneNumberAuthenticationParameter param,
  ) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber:
            UtilityFunctions.addCountryCodeToPhoneNumber(param.phoneNumber),
        verificationCompleted: (credentials) => _verificationCompleted(
          credentials,
          param.onVerificationCompleted,
          param.onVerificationFailed,
        ),
        verificationFailed: (authException) => _verificationFailed(
          param.phoneNumber,
          authException,
          param.onVerificationFailed,
        ),
        codeSent: (verificationId, resendToken) => _codeSent(
          verificationId,
          resendToken,
          param.phoneNumber,
          param.onVerificationCodeSent,
        ),
        codeAutoRetrievalTimeout: (verificationId) => _codeAutoRetrievalTimeout(
          verificationId,
          param.onVerificationAutoRetrievalTimeout,
        ),
      );
    } on FirebaseAuthException catch (e) {
      UtilityFunctions.debugPrint(
          '\t\t\t Authentication with phone number failed with exception');
      UtilityFunctions.debugPrint('\n$e', leadingIcons: '😓😓😓');

      return AuthenticationResponse.verificationFailed;
    }
    return AuthenticationResponse.verificationSuccessful;
  }

  void _verificationCompleted(
    AuthCredential credential,
    Function onVerificationCompleted,
    void Function(String) onVerificationFailed,
  ) async {
    UtilityFunctions.debugPrint('Automatic phone verification.');

    try {
      final credentialResult =
          await _firebaseAuth.signInWithCredential(credential);
      UtilityFunctions.debugPrint('verification completed$credentialResult',
          leadingIcons: '👍');
    } on FirebaseAuthException catch (e) {
      UtilityFunctions.debugPrint('\t\t\t Exception in during verification');
      UtilityFunctions.debugPrint('\n$e', leadingIcons: '😓😓😓');
      onVerificationFailed(e.code);

      return;
    }

    onVerificationCompleted();
  }

  void _verificationFailed(
    String phoneNumber,
    FirebaseAuthException exception,
    void Function(String) onVerificationFailed,
  ) {
    UtilityFunctions.debugPrint('verification failed $exception',
        leadingIcons: '🚫🚫🚫');

    onVerificationFailed(exception.code);
  }

  void _codeSent(
    String verificationId,
    int? resendToken,
    String phoneNumber,
    Function onVerificationCodeSent,
  ) {
    UtilityFunctions.debugPrint(
      'code sent verificationId = $verificationId && verificationToken = $resendToken',
      leadingIcons: '📲',
    );
    _otpVerificationIds[phoneNumber] = verificationId;
    _resendTokens[phoneNumber] = resendToken;

    onVerificationCodeSent();
  }

  void _codeAutoRetrievalTimeout(
    String verificationId,
    Function onVerificationAutoRetrievalTimeout,
  ) {
    UtilityFunctions.debugPrint(
      'codeAutoRetrievalTimeout: $verificationId',
      leadingIcons: '🚧',
    );

    onVerificationAutoRetrievalTimeout();
  }

  @override
  Future<AuthenticationResponse> authenticateWithOTPCode(
    String phoneNumber,
    String otpCode, {
    required Function onVerificationCompleted,
    required Function(String) onVerificationFailed,
  }) async {
    final verificationId = _otpVerificationIds[phoneNumber];
    if (verificationId == null) {
      UtilityFunctions.debugPrint(
          'Attempt to confirm an OTP code before doing an'
          ' authentication with phone number.',
          leadingIcons: '🚫');

      return AuthenticationResponse.verificationFailed;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpCode,
      );
      final credentialResult =
          await _firebaseAuth.signInWithCredential(credential);
      UtilityFunctions.debugPrint(
          'signInWithCredential done with result $credentialResult',
          leadingIcons: '👍');
      onVerificationCompleted();
    } catch (exception) {
      UtilityFunctions.debugPrint(
          '\t\t\tException in phone_authentication_controller.dart');
      UtilityFunctions.debugPrint('\n$exception', leadingIcons: '😓😓😓');
      onVerificationFailed('$exception');
      return AuthenticationResponse.verificationFailed;
    }
    return AuthenticationResponse.verificationSuccessful;
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  String? get uid => _firebaseAuth.currentUser?.uid;

  @override
  User? get user => _firebaseAuth.currentUser;
}
