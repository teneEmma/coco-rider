/// Build-time configuration, passed with `--dart-define`:
///
/// ```
/// flutter run \
///   --dart-define=COCO_API_URL=https://xxxx.execute-api.eu-west-1.amazonaws.com \
///   --dart-define=COCO_COGNITO_REGION=eu-west-1 \
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
      String.fromEnvironment('COCO_COGNITO_REGION', defaultValue: 'eu-west-1');

  static const String cognitoClientId =
      String.fromEnvironment('COCO_COGNITO_CLIENT_ID');

  static bool get usesCognito => cognitoClientId.isNotEmpty;
}
