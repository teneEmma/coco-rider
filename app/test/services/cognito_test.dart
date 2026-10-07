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
/// Without a SignUp handler the account already exists (UsernameExistsException), as for a returning user.
MockClient cognitoMock(List<String> calls, Map<String, http.Response Function(Map<String, dynamic>)> handlers) =>
    MockClient((request) async {
      final action = request.headers['X-Amz-Target']!.split('.').last;
      calls.add(action);
      final handler = handlers[action];
      if (handler == null && action == 'SignUp') {
        return http.Response('{"__type":"UsernameExistsException","message":"User already exists"}', 400);
      }
      if (handler == null) return http.Response('{"__type":"Unexpected#$action"}', 400);
      return handler(jsonDecode(request.body) as Map<String, dynamic>);
    });

http.Response ok(Map<String, dynamic> body) => http.Response(jsonEncode(body), 200);

Map<String, dynamic> tokens({int expiresIn = 3600, String? refresh = 'refresh-1', Map<String, dynamic>? claims}) => {
      'AuthenticationResult': {
        'IdToken': fakeJwt(claims ?? {'sub': 'sub-1', 'phone_number': phone, 'phone_number_verified': true}),
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
    expect(calls, ['SignUp', 'InitiateAuth', 'RespondToAuthChallenge']);
  });

  test('new phone number is registered, confirmed and signed in', () async {
    final calls = <String>[];
    final client = CognitoClient(
      region: 'eu-west-1',
      clientId: 'client',
      httpClient: cognitoMock(calls, {
        // After sign-up confirmation only: an unknown number never reaches InitiateAuth first.
        'InitiateAuth': (body) {
          expect(body['Session'], 'after-signup');
          return ok(tokens());
        },
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
    expect(calls, ['SignUp', 'ConfirmSignUp', 'InitiateAuth']);
  });

  test('an account created earlier but never confirmed gets a new code', () async {
    final calls = <String>[];
    final client = CognitoClient(
      region: 'eu-west-1',
      clientId: 'client',
      httpClient: cognitoMock(calls, {
        'InitiateAuth': (_) => http.Response('{"__type":"UserNotConfirmedException","message":"not confirmed"}', 400),
        'ResendConfirmationCode': (body) {
          expect(body['Username'], phone);
          return ok({});
        },
      }),
    );

    final pending = await client.sendCode(phone);

    expect(pending.challenge, CognitoChallenge.signUp);
    expect(calls, ['SignUp', 'InitiateAuth', 'ResendConfirmationCode']);
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

  test('new email address is registered with an emailed code, then signed in', () async {
    const email = 'ama@example.com';
    final calls = <String>[];
    final cognito = CognitoClient(
      region: 'eu-west-1',
      clientId: 'client',
      httpClient: cognitoMock(calls, {
        'InitiateAuth': (body) {
          if (body['Session'] == 'confirmed') {
            return ok(tokens(claims: {'sub': 'sub-2', 'email': email, 'email_verified': true}));
          }
          fail('a new address is signed up, not signed in');
        },
        'SignUp': (body) {
          expect(body['Username'], email);
          expect(body['UserAttributes'], [
            {'Name': 'email', 'Value': email},
          ]);
          return ok({'UserConfirmed': false});
        },
        'ConfirmSignUp': (body) {
          expect(body['ConfirmationCode'], '654321');
          return ok({'Session': 'confirmed'});
        },
      }),
    );
    final auth = AuthCognitoImplementation(cognito: cognito, store: MemoryTokenStore());

    var sent = false;
    await auth.authenticateWithEmail(EmailAuthenticationParameter(
      email: ' Ama@Example.com ',
      onVerificationCodeSent: () => sent = true,
      onVerificationFailed: (e) => fail('unexpected $e'),
    ));
    await auth.authenticateWithOTPCode(email, '654321', onVerificationCompleted: () {}, onVerificationFailed: (e) => fail(e));

    expect(sent, isTrue);
    expect(calls, ['SignUp', 'ConfirmSignUp', 'InitiateAuth']);
    expect(auth.user?.email, email);
    expect(auth.user?.signedInWithEmail, isTrue);
  });

  test('existing email user answers the EMAIL_OTP challenge', () async {
    final cognito = CognitoClient(
      region: 'eu-west-1',
      clientId: 'client',
      httpClient: cognitoMock([], {
        'InitiateAuth': (_) => ok({'ChallengeName': 'EMAIL_OTP', 'Session': 'session-e'}),
        'RespondToAuthChallenge': (body) {
          expect(body['ChallengeName'], 'EMAIL_OTP');
          expect(body['ChallengeResponses']['EMAIL_OTP_CODE'], '111111');
          return ok(tokens());
        },
      }),
    );
    final pending = await cognito.sendCode('ama@example.com', channel: SignInChannel.email);
    await cognito.confirmCode('ama@example.com', pending, '111111');
  });

  test('an unverified phone number in the token does not count', () async {
    final cognito = CognitoClient(
      region: 'eu-west-1',
      clientId: 'client',
      httpClient: cognitoMock([], {
        'InitiateAuth': (_) => ok({'ChallengeName': 'EMAIL_OTP', 'Session': 's'}),
        'RespondToAuthChallenge': (_) => ok(tokens(claims: {
              'sub': 'sub-3',
              'email': 'x@example.com',
              'phone_number': phone,
              'phone_number_verified': false,
            })),
      }),
    );
    final auth = AuthCognitoImplementation(cognito: cognito, store: MemoryTokenStore());
    await auth.authenticateWithEmail(EmailAuthenticationParameter(
      email: 'x@example.com',
      onVerificationCodeSent: () {},
      onVerificationFailed: (_) {},
    ));
    await auth.authenticateWithOTPCode('x@example.com', '123456', onVerificationCompleted: () {}, onVerificationFailed: (_) {});

    expect(auth.user?.phoneNumber, isEmpty);
    expect(auth.user?.signedInWithEmail, isTrue);
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
