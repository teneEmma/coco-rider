import 'dart:convert';

import 'package:http/http.dart' as http;

/// Tokens returned by Cognito after a successful sign-in.
class CognitoTokens {
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;

  CognitoTokens({
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool get isExpiringSoon =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));

  Map<String, dynamic> toJson() => {
        'idToken': idToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory CognitoTokens.fromJson(Map<String, dynamic> json) => CognitoTokens(
        idToken: json['idToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  /// The claims of the ID token (not verified here; the API verifies it).
  Map<String, dynamic> get claims {
    final payload = idToken.split('.')[1];
    return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))))
        as Map<String, dynamic>;
  }
}

class CognitoException implements Exception {
  /// Cognito error type, e.g. "CodeMismatchException", "UserNotFoundException".
  final String type;
  final String message;

  CognitoException(this.type, this.message);

  @override
  String toString() => 'CognitoException($type): $message';
}

/// What the user must do after asking for a code.
enum CognitoChallenge {
  /// Existing user: the code signs them in.
  signIn,

  /// New user: the code confirms their phone number, then signs them in.
  signUp,
}

/// Where the one-time code is sent.
enum SignInChannel {
  /// SMS to a phone number (the username is the E.164 number).
  phone,

  /// Email (the username is the email address).
  email,
}

/// A code was sent by SMS or email; keep this to confirm it.
class PendingCode {
  final CognitoChallenge challenge;
  final String? session;
  final SignInChannel channel;

  PendingCode(this.challenge, this.session, [this.channel = SignInChannel.phone]);
}

/// Passwordless sign-in and sign-up with a code sent by SMS or email, through the Cognito API.
/// Public app clients need no request signing, so plain HTTP calls are enough.
class CognitoClient {
  final String region;
  final String clientId;
  final http.Client _http;

  CognitoClient({
    required this.region,
    required this.clientId,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Uri get _endpoint => Uri.parse('https://cognito-idp.$region.amazonaws.com/');

  /// Sends a code by SMS (phone number) or email. New users are registered on the fly.
  Future<PendingCode> sendCode(String username,
      {SignInChannel channel = SignInChannel.phone}) async {
    final challenge = _challengeName(channel);
    try {
      final response = await _call('InitiateAuth', {
        'AuthFlow': 'USER_AUTH',
        'ClientId': clientId,
        'AuthParameters': {
          'USERNAME': username,
          'PREFERRED_CHALLENGE': challenge,
        },
      });
      if (response['ChallengeName'] != challenge) {
        throw CognitoException(
            'UnexpectedChallenge', '${response['ChallengeName']}');
      }
      return PendingCode(
          CognitoChallenge.signIn, response['Session'] as String, channel);
    } on CognitoException catch (e) {
      if (e.type != 'UserNotFoundException') rethrow;
    }

    await _call('SignUp', {
      'ClientId': clientId,
      'Username': username,
      'UserAttributes': [
        {
          'Name': channel == SignInChannel.email ? 'email' : 'phone_number',
          'Value': username,
        },
      ],
    });
    return PendingCode(CognitoChallenge.signUp, null, channel);
  }

  Future<CognitoTokens> confirmCode(
      String username, PendingCode pending, String code) async {
    if (pending.challenge == CognitoChallenge.signIn) {
      final challenge = _challengeName(pending.channel);
      final response = await _call('RespondToAuthChallenge', {
        'ChallengeName': challenge,
        'ClientId': clientId,
        'Session': pending.session,
        'ChallengeResponses': {
          'USERNAME': username,
          '${challenge}_CODE': code,
        },
      });
      return _tokens(response['AuthenticationResult'], null);
    }

    // Sign-up: confirming the phone number or email returns a session that signs the user in directly.
    final confirmed = await _call('ConfirmSignUp', {
      'ClientId': clientId,
      'Username': username,
      'ConfirmationCode': code,
    });
    final response = await _call('InitiateAuth', {
      'AuthFlow': 'USER_AUTH',
      'ClientId': clientId,
      'Session': confirmed['Session'],
      'AuthParameters': {'USERNAME': username},
    });
    return _tokens(response['AuthenticationResult'], null);
  }

  static String _challengeName(SignInChannel channel) =>
      channel == SignInChannel.email ? 'EMAIL_OTP' : 'SMS_OTP';

  Future<CognitoTokens> refresh(String refreshToken) async {
    final response = await _call('InitiateAuth', {
      'AuthFlow': 'REFRESH_TOKEN_AUTH',
      'ClientId': clientId,
      'AuthParameters': {'REFRESH_TOKEN': refreshToken},
    });
    return _tokens(response['AuthenticationResult'], refreshToken);
  }

  CognitoTokens _tokens(dynamic result, String? previousRefreshToken) {
    if (result is! Map<String, dynamic>) {
      throw CognitoException('MissingTokens', 'Cognito returned no tokens.');
    }
    return CognitoTokens(
      idToken: result['IdToken'] as String,
      refreshToken:
          (result['RefreshToken'] as String?) ?? previousRefreshToken ?? '',
      expiresAt: DateTime.now()
          .add(Duration(seconds: (result['ExpiresIn'] as num).toInt())),
    );
  }

  Future<Map<String, dynamic>> _call(
      String action, Map<String, dynamic> body) async {
    final response = await _http.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.$action',
      },
      body: jsonEncode(body),
    );
    final json = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final type = (json['__type'] as String? ?? 'Unknown').split('#').last;
      throw CognitoException(type, json['message'] as String? ?? type);
    }
    return json;
  }
}
