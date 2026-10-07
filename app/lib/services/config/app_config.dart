/// Build-time configuration, passed with `--dart-define`:
///
/// ```
/// flutter run \
///   --dart-define=COCO_API_URL=https://xxxx.execute-api.us-east-1.amazonaws.com \
///   --dart-define=COCO_COGNITO_REGION=us-east-1 \
///   --dart-define=COCO_COGNITO_CLIENT_ID=xxxxxxxx
/// ```
///
/// Without a Cognito client id the app talks to a local API in development mode
/// (no SMS: the code is always 123456).
class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'COCO_API_URL',
    // 10.0.2.2 is the host machine seen from the Android emulator.
    defaultValue: 'http://10.0.2.2:5200',
  );

  static const String cognitoRegion =
      String.fromEnvironment('COCO_COGNITO_REGION', defaultValue: 'us-east-1');

  static const String cognitoClientId =
      String.fromEnvironment('COCO_COGNITO_CLIENT_ID');

  static bool get usesCognito => cognitoClientId.isNotEmpty;

  /// Offer sign-in by email. Always on with the local API; on AWS only once the user pool can send
  /// email codes (`senderEmail` set in infra/cdk.json): `--dart-define=COCO_EMAIL_SIGN_IN=true`.
  static const bool _emailSignInFlag = bool.fromEnvironment('COCO_EMAIL_SIGN_IN');

  static bool get emailSignIn => !usesCognito || _emailSignInFlag;
}
