import 'dart:convert';

import 'package:coco_rider/services/authentication/auth_cognito_implementation.dart';
import 'package:coco_rider/services/authentication/base_authentication.dart';
import 'package:coco_rider/services/authentication/cognito_client.dart';
import 'package:coco_rider/services/authentication/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers.dart';

const phone = '+237690000001';

/// Fakes the Cognito API; [handlers] answer per X-Amz-Target action.
MockClient cognitoMock(List<String> calls, Map<String, http.Response Function(Map<String, dynamic>)> handlers) =>
    MockClient((request) async {
      final action = request.headers['X-Amz-Target']!.split('.').last;
      calls.add(action);
      final handler = handlers[action];
      if (handler == null) return http.Response('{"__type":"Unexpected#$action"}', 400);
      return handler(jsonDecode(request.body) as Map<String, dynamic>);
    });

http.Response ok(Map<String, dynamic> body) => http.Response(jsonEncode(body), 200);

Map<String, dynamic> tokens({int expiresIn = 3600, String? refresh = 'refresh-1'}) => {
      'AuthenticationResult': {
        'IdToken': fakeJwt({'sub': 'sub-1', 'phone_number': phone}),
        if (refresh != null) 'RefreshToken': refresh,
        'ExpiresIn': expiresIn,
      },
    };

void main() {
  test('existing user signs in with the SMS code', () async {
    final calls = <String>[];
    final client = CognitoClient(
      region: 'eu-west-1',
      clientId: 'client',
      httpClient: cognitoMock(calls, {
        'InitiateAuth': (body) {
          expect(body['AuthFlow'], 'USER_AUTH');
          expect(body['AuthParameters']['PREFERRED_CHALLENGE'], 'SMS_OTP');
          return ok({'ChallengeName': 'SMS_OTP', 'Session': 'session-1'});
        },
        'RespondToAuthChallenge': (body) {
          expect(body['Session'], 'session-1');
          expect(body['ChallengeResponses']['SMS_OTP_CODE'], '123456');
          return ok(tokens());
        },
      }),
    );

    final pending = await client.sendCode(phone);
    final result = await client.confirmCode(phone, pending, '123456');

    expect(pending.challenge, CognitoChallenge.signIn);
    expect(result.claims['sub'], 'sub-1');
    expect(calls, ['InitiateAuth', 'RespondToAuthChallenge']);
  });

  test('new phone number is registered, confirmed and signed in', () async {
    final calls = <String>[];
    final client = CognitoClient(
      region: 'eu-west-1',
      clientId: 'client',
      httpClient: cognitoMock(calls, {
        'InitiateAuth': (body) => body['Session'] == 'after-signup'
            ? ok(tokens())
            : http.Response('{"__type":"UserNotFoundException","message":"User does not exist."}', 400),
        'SignUp': (body) {
          expect(body['UserAttributes'], [
            {'Name': 'phone_number', 'Value': phone},
          ]);
          return ok({'UserConfirmed': false});
        },
        'ConfirmSignUp': (body) {
          expect(body['ConfirmationCode'], '654321');
          return ok({'Session': 'after-signup'});
        },
      }),
    );

    final pending = await client.sendCode(phone);
    await client.confirmCode(phone, pending, '654321');

    expect(pending.challenge, CognitoChallenge.signUp);
    expect(calls, ['InitiateAuth', 'SignUp', 'ConfirmSignUp', 'InitiateAuth']);
  });

  test('wrong code is reported with the Cognito error type', () async {
    final client = CognitoClient(
      region: 'eu-west-1',
      clientId: 'client',
      httpClient: cognitoMock([], {
        'RespondToAuthChallenge': (_) => http.Response('{"__type":"CodeMismatchException","message":"Invalid code"}', 400),
      }),
    );

    expect(
      () => client.confirmCode(phone, PendingCode(CognitoChallenge.signIn, 's'), '000000'),
      throwsA(isA<CognitoException>().having((e) => e.type, 'type', 'CodeMismatchException')),
    );
  });

  test('session is saved, restored and refreshed before it expires', () async {
    final calls = <String>[];
    final store = MemoryTokenStore();
    final cognito = CognitoClient(
      region: 'eu-west-1',
      clientId: 'client',
      httpClient: cognitoMock(calls, {
        'InitiateAuth': (body) => body['AuthFlow'] == 'REFRESH_TOKEN_AUTH'
            ? ok(tokens(refresh: null))
            : ok({'ChallengeName': 'SMS_OTP', 'Session': 's'}),
        // Token that expires within the minute: the next API call refreshes it.
        'RespondToAuthChallenge': (_) => ok(tokens(expiresIn: 30)),
      }),
    );
    final auth = AuthCognitoImplementation(cognito: cognito, store: store);

    await auth.authenticateWithPhoneNumber(PhoneNumberAuthenticationParameter(
      phoneNumber: phone,
      onVerificationCompleted: () {},
      onVerificationFailed: (_) {},
      onVerificationCodeSent: () {},
      onVerificationAutoRetrievalTimeout: () {},
    ));
    var completed = false;
    await auth.authenticateWithOTPCode(phone, '123456',
        onVerificationCompleted: () => completed = true, onVerificationFailed: (_) {});

    expect(completed, isTrue);
    expect(auth.user?.phoneNumber, phone);

    final restored = AuthCognitoImplementation(cognito: cognito, store: store);
    expect(await restored.restoreSession(), isTrue);

    final headers = await restored.authHeaders();
    expect(headers['Authorization'], startsWith('Bearer '));
    expect(calls.last, 'InitiateAuth');
    expect(jsonDecode((await store.read())!)['refreshToken'], 'refresh-1');
  });
}
