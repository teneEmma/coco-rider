void main() {
// Create a RegExp object with the regex pattern as a raw string
  RegExp regExp = RegExp(r'(\d{4})(?=\d)');

// Apply the regex to a string using replaceAll method

  String result = '1234567890'.replaceAll(regExp, r'\\G ');

// Print the result
  print(result); // 1234 5678 90
}

// TODO: All these auth stuffs should be kept in an appSpecific Class called Auth.
await FirebaseAuth.instance.verifyPhoneNumber(
phoneNumber: addCountryCodeToPhoneNumber(phoneNumberTextController.text),
verificationCompleted: (phoneAuthCredential) {
print('👍 verification completed$phoneAuthCredential');
setButtonState(CocoButtonState.onSuccess);
},
verificationFailed: (authException) {
print('🚫 verification failed $authException');
switch (authException.code) {
case 'network-request-failed':
// Todo: Show snackbar to tell user there is no internet connection,
setButtonState(CocoButtonState.initialState);
default:
setButtonState(CocoButtonState.onError);
}
},
codeSent: (verifId, token) {
print('📲 code sent $verifId && $token');
setButtonState(CocoButtonState.onSuccess);
authVerificationCode = verifId;
Get.toNamed(CocoRoutes.keyOTPVerificationCodePage);
},
codeAutoRetrievalTimeout: (verifId) {},


//
// import 'dart:async';
//
// import 'package:flutter/foundation.dart';
// import 'package:logging/logging.dart';
// import 'package:spreeloop_core_analytics/analytics.dart';
// import 'package:spreeloop_core_authentication/authentication.dart';
// import 'package:spreeloop_core_cloud_function/cloud_function.dart';
// import 'package:spreeloop_place_common_models/models.dart';
// import 'package:spreeloop_place_common_repositories/repositories.dart';
//
// /// Authentication operation types of results.
// /// This allows us to give meaningful error messages to users.
// class AuthErrorCodes {
//   /// Auth operation succeeded.
//   static const success = 'success';
//
//   /// An attempt to login as an un-authenticated user (no uid).
//   static const errorLoginUnAuthenticated = 'error-login-unauthenticated';
//
//   /// An attempt to register as an un-authenticated user (no uid).
//   static const errorRegisterUnAuthenticated = 'error-register-unauthenticated';
//
//   /// An attempt to login as an anonymous user.
//   static const errorLoginUnVerified = 'error-login-unverified';
//
//   /// An attempt to register as an anonymous user.
//   static const errorRegisterUnVerified = 'error-register-unverified';
//
//   /// A failure to write to the database.
//   /// Probably permission issues or missing user identifier.
//   static const errorDatabaseWrite = 'error-database-write';
//
//   /// A failure to read from the database.
//   /// Probably permission issues or missing user identifier.
//   static const errorDatabaseRead = 'error-database-read';
//
//   /// A failure to begin the auth using a phone number.
//   static const errorPhoneAuthSetup = 'error-phone-auth-setup';
//
//   /// A failure to begin the auth using an OTP code.
//   static const errorOTPAuthSetup = 'error-otp-auth-setup';
//
//   /// A failure for a reason we do not want to display to the user.
//   static const errorInternal = 'error-internal-reason';
// }
//
// class _AuthUserData {
//   final String? firstName;
//   final String? lastName;
//   final String? email;
//   final String? phoneNumber;
//
//   _AuthUserData.anonymous()
//       : firstName = null,
//         lastName = null,
//         email = null,
//         phoneNumber = null;
//
//   _AuthUserData.loggedIn({
//     required this.firstName,
//     required this.lastName,
//     required this.email,
//     required this.phoneNumber,
//   });
// }
//
// /// This class handles everything related with authentication.
// class Auth extends ChangeNotifier {
//   final _log = Logger('Auth');
//   final Completer<bool> _authInitComplete = Completer<bool>();
//   final Authentication _authSubsystem;
//   final UsersRepository _usersRepository;
//   final CloudFunction _cloudFunction;
//   final Analytics _analytics;
//   final StreamController<String?> _authLoginStreamController =
//   StreamController.broadcast();
//   final StreamController<String?> _authLogoutStreamController =
//   StreamController.broadcast();
//
//   _AuthUserData _authUserData = _AuthUserData.anonymous();
//   bool _userIsLogged = false;
//
//   /// Returns the user's phone number.
//   String get userPhoneNumber => _authUserData.phoneNumber ?? '';
//
//   /// Returns the user's first name.
//   String get userFirstName => _authUserData.firstName ?? '';
//
//   /// Returns the user's last name.
//   String get userLastName => _authUserData.lastName ?? '';
//
//   /// Returns the user's email.
//   String get userEmail => _authUserData.email ?? '';
//
//   /// Checks if the user is logged in.
//   bool get userIsLogged => _userIsLogged;
//
//   /// Returns the User Id.
//   String? get userId => _authSubsystem.uid;
//
//   /// Returns true when auth initialization completes.
//   Future<bool> get authComplete => _authInitComplete.future;
//
//   /// Returns Stream to track user logins.
//   Stream<String?> get authLoginStream => _authLoginStreamController.stream;
//
//   /// Returns Stream to track user logouts.
//   Stream<String?> get authLogoutStream => _authLogoutStreamController.stream;
//
//   /// Constructs the auth object.
//   Auth._(
//       this._authSubsystem,
//       this._usersRepository,
//       this._analytics,
//       this._cloudFunction,
//       ) {
//     final subsystemInitialized = _authSubsystem.initialized().timeout(
//       Duration(seconds: 5),
//       onTimeout: () {
//         _log.warning('Timeout waiting for the Auth subsystem initialization');
//         return;
//       },
//     );
//
//     subsystemInitialized.then((_) async {
//       _log.info('Initializing common Auth');
//
//       // Listen to subsystem changes only after Auth has been initialized.
//       // This ensures that the subsystem does not interfere we the common Auth
//       // initialization.
//       await _init();
//       _authSubsystem.authStateChanges().listen(_onSubsystemChanges);
//
//       return;
//     });
//   }
//
//   Future<void> _init() async {
//     if (userId == null) {
//       _log.info('Initialized null user as anonymous');
//       _authInitComplete.complete(_authenticateAnonymously());
//       return;
//     }
//
//     if (!_authSubsystem.isUserVerified()) {
//       _log.info('Initialized as an already anonymous user');
//       _authInitComplete.complete(true);
//       return;
//     }
//
//     // The current user is already verified. Attempt to log them in.
//     // If log-in fails. Sign them in anonymously.
//     final result = await login();
//     _log.info('Attempt to log-in verified user');
//     if (result == AuthErrorCodes.success) {
//       _authInitComplete.complete(true);
//       return;
//     }
//
//     _log.info(
//       'Initialized verified user as anonymous (log-in failed: $result)',
//     );
//     _authInitComplete.complete(_authenticateAnonymously());
//   }
//
//   /// Constructs the Authentication using an Auth type.
//   factory Auth(
//       AuthType authType,
//       UsersRepository usersRepository,
//       Analytics analytics,
//       CloudFunction cloudFunction,
//       ) {
//     return Auth._(
//       Authentication(authType),
//       usersRepository,
//       analytics,
//       cloudFunction,
//     );
//   }
//
//   /// Constructs the Authentication service using a fake implementation.
//   factory Auth.fake(
//       UsersRepository usersRepository,
//       CloudFunction cloudFunction,
//       Analytics analytics, {
//         String? uid,
//         String? testPhoneNumber,
//         String? testSmsCode,
//       }) {
//     return Auth._(
//       Authentication.fake(
//         uid: uid,
//         testPhoneNumber: testPhoneNumber,
//         testSmsCode: testSmsCode,
//       ),
//       usersRepository,
//       analytics,
//       cloudFunction,
//     );
//   }
//
//   /// Returns the userId associated with the phone number in the database.
//   ///
//   /// Returns null if the phone number does not exist in the database.
//   Future<String?> getUserByPhoneNumber(String phoneNumber) async {
//     final user = await _usersRepository.getUserByPhoneNumber(phoneNumber, []);
//
//     return user?.uid;
//   }
//
//   void _resetAuthState() {
//     _log.info('Resetting auth state.');
//
//     // Nullify the user data locally.
//     _authUserData = _AuthUserData.anonymous();
//
//     // Update the user login state.
//     // Invalidate the login state, because a different user ID may be assigned
//     // to the user.
//     _userIsLogged = false;
//   }
//
//   /// Authenticates an anonymous (unverified) user.
//   Future<bool> _authenticateAnonymously() async {
//     _log.info('Anonymous authentication started.');
//     final success = await _authSubsystem.authenticateAnonymously();
//     if (success) {
//       _resetAuthState();
//       notifyListeners();
//     }
//
//     return success;
//   }
//   //
//   // /// Attempts to authenticate and verify a user using their phone number.
//   // Future<bool> authenticateWithPhoneNumber(
//   //     PhoneNumberAuthenticationParameter param,
//   //     ) async {
//   //   _log.info('Phone number authentication started.');
//   //   await _authInitComplete.future;
//   //
//   //   // Log-out a user, if they attempt to authenticate while they are already
//   //   // logged-in.
//   //   if (_userIsLogged) {
//   //     _log.info(
//   //       'Attempting to authenticate with phone while a user is logged-in.'
//   //           ' We will log them out first.',
//   //     );
//   //     final logoutSuccess = await logout();
//   //     if (!logoutSuccess) {
//   //       _log.severe(
//   //         'Failed to log user out before authentication with phone number.',
//   //       );
//   //
//   //       return false;
//   //     }
//   //   }
//   //
//   //   return _authSubsystem.authenticateWithPhoneNumber(param);
//   // }
//   // /// Attempts to authenticate and verify a user using their phone number and
//   // /// an OTP code.
//   // Future<bool> authenticateWithOTPCode(
//   //     String phoneNumber,
//   //     String otpCode, {
//   //       required VoidCallback onVerificationCompleted,
//   //       required void Function(String) onVerificationFailed,
//   //     }) async {
//   //   _log.info('OTP authentication started.');
//   //   await _authInitComplete.future;
//   //
//   //   // Log-out a user, if they attempt to authenticate while they are already
//   //   // logged-in.
//   //   if (_userIsLogged) {
//   //     _log.info('Attempting to authenticate with OTP while a user is logged-in.'
//   //         ' We will log them out first.');
//   //     final logoutSuccess = await logout();
//   //     if (!logoutSuccess) {
//   //       _log.severe(
//   //         'Failed to log user out before authentication with OTP code.',
//   //       );
//   //       onVerificationFailed(AuthErrorCodes.errorOTPAuthSetup);
//   //
//   //       return false;
//   //     }
//   //   }
//   //
//   //   return _authSubsystem.authenticateWithOTPCode(
//   //     phoneNumber,
//   //     otpCode,
//   //     onVerificationCompleted: onVerificationCompleted,
//   //     onVerificationFailed: onVerificationFailed,
//   //   );
//   // }
//
//   /// Logs-in an already verified user.
//   /// To authenticate a user, use one of the authenticateWithXXX methods.
//   Future<String> login() async {
//     _log.info('Log-in started.');
//
//     // Ensure that the user is authenticated (at least anonymous).
//     final identifier = userId;
//     if (identifier == null) {
//       _log.severe('Attempt to login a non-authenticated (null) user');
//
//       return AuthErrorCodes.errorLoginUnAuthenticated;
//     }
//
//     // Ensure that the user is already verified.
//     if (!_authSubsystem.isUserVerified()) {
//       _log.severe('Attempt to login a user ($identifier) that is not verified');
//
//       return AuthErrorCodes.errorLoginUnVerified;
//     }
//
//     // Fetch the user information from the database.
//     final user = await _usersRepository.getUserById(identifier);
//     if (user == null) {
//       _log.severe('Attempt to login a user ($identifier) that does not'
//           ' exist in the database');
//
//       return AuthErrorCodes.errorDatabaseRead;
//     }
//     if (identifier != user.uid) {
//       _log.severe(
//         'Auth ID and document uid mismatch. $identifier vs. ${user.uid}',
//       );
//     }
//
//     // Update the user data locally.
//     _authUserData = _AuthUserData.loggedIn(
//       firstName: user.firstName,
//       lastName: user.lastName,
//       email: user.email,
//       phoneNumber: user.phoneNumber,
//     );
//
//     // Update the user login state.
//     _userIsLogged = true;
//
//     // Register the analytics event.
//     unawaited(
//       _analytics.logEvent(
//         eventType: EventType.login,
//         parameters: {UserParam.userId: identifier},
//       ),
//     );
//
//     _onUserLoggedIn(userId);
//
//     return AuthErrorCodes.success;
//   }
//
//   /// Registers an already verified user.
//   /// To authenticate a user, use one of the authenticateWithXXX methods.
//   Future<String> register({
//     required String firstName,
//     required String lastName,
//     required String phoneNumber,
//     required String? referredBy,
//     String? email,
//   }) async {
//     _log.info('Registration started.');
//
//     // Ensure that the user is authenticated (at least anonymous).
//     final identifier = userId;
//     if (identifier == null) {
//       _log.severe('Attempt to register a non-authenticated (null) user');
//
//       return AuthErrorCodes.errorRegisterUnAuthenticated;
//     }
//
//     // Ensure that the user is already verified.
//     if (!_authSubsystem.isUserVerified()) {
//       _log.severe(
//         'Attempt to register a user ($identifier) that is not verified',
//       );
//
//       return AuthErrorCodes.errorRegisterUnVerified;
//     }
//
//     // Set the user information in the database.
//     // TODO: use 'null' instead of an empty string for missing email.
//     // This is temporary until clients migrate to versions that consider email
//     // as an optional field.
//     // https://app.asana.com/0/1188745543018673/1202019487063576
//     final userCreated = await _usersRepository.createUserRecord(
//       User(
//         uid: identifier,
//         firstName: firstName,
//         lastName: lastName,
//         email: email ?? '',
//         phoneNumber: phoneNumber,
//       ),
//     );
//     if (!userCreated) {
//       _log.severe('Failed to add the user $userId with phone number '
//           '$phoneNumber to the database. Permission issues?');
//
//       return AuthErrorCodes.errorDatabaseWrite;
//     }
//
//     // Updates the Place customer specific information.
//     if (referredBy != null) {
//       await _usersRepository.updateReferredByCode(identifier, referredBy);
//     }
//
//     // Update the user data locally.
//     _authUserData = _AuthUserData.loggedIn(
//       firstName: firstName,
//       lastName: lastName,
//       email: email,
//       phoneNumber: phoneNumber,
//     );
//
//     // Update the user login state.
//     _userIsLogged = true;
//
//     // Register the analytics event.
//     unawaited(
//       _analytics.logEvent(
//         eventType: EventType.signUp,
//         parameters: {UserParam.userId: identifier},
//       ),
//     );
//
//     _onUserLoggedIn(userId);
//
//     return AuthErrorCodes.success;
//   }
//
//
// }
