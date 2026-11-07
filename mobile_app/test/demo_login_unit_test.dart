// The DEMO LOGIN of the real login code (SupabaseAuthService), with a fake
// web server (no internet): what is asked to the Edge Function "demo-auth",
// when the normal SMS code is used instead, and how its answers become the
// app's messages.
// Run it with: flutter test
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/data/auth_service.dart';

const phone = '+21622123456';
const userId = '11111111-2222-4333-8444-555555555555';

String _part(Map<String, Object?> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// A session like the one Supabase Auth gives (an unsigned JWT is enough).
Map<String, Object?> _session(String refreshToken) {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  return {
    'access_token':
        '${_part({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${_part({'sub': userId, 'exp': exp, 'role': 'authenticated', 'aud': 'authenticated'})}.c2ln',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': exp,
    'refresh_token': refreshToken,
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'phone': '21622123456',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-11-03T00:00:00Z',
    },
  };
}

/// A fake Supabase: the Edge Function answers [start] / [verify] (status,
/// JSON); [calls] = what the app asked, in order.
class FakeServer {
  (int, Object?) start = (200, {'demo': true});
  (int, Object?) verify = (
    200,
    {'refresh_token': 'rt-demo', 'user_id': userId},
  );
  bool offline = false;
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];

  http.Response _json(int status, Object? body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  late final client = MockClient((request) async {
    if (offline) throw http.ClientException('Failed host lookup');
    final path = request.url.path;
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    bodies.add(body);
    if (path == '/functions/v1/demo-auth') {
      calls.add('demo-auth ${body['action']}');
      final (status, answer) = body['action'] == 'start' ? start : verify;
      return _json(status, answer);
    }
    if (path == '/auth/v1/otp') {
      calls.add('SMS code');
      return _json(200, <String, Object?>{});
    }
    if (path == '/auth/v1/verify') {
      calls.add('check SMS code');
      return _json(200, _session('rt-sms'));
    }
    if (path == '/auth/v1/token') {
      calls.add('session from ${body['refresh_token']}');
      return _json(200, _session('rt-new'));
    }
    return _json(404, {'message': 'not found'});
  });
}

void main() {
  late FakeServer server;
  late SupabaseClient supabase;
  late SupabaseAuthService service;

  setUp(() {
    server = FakeServer();
    supabase = SupabaseClient(
      'https://test.supabase.co',
      'test-publishable-key',
      httpClient: server.client,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );
    service = SupabaseAuthService(supabase);
  });
  tearDown(() => supabase.dispose());

  Future<AuthFailure?> failureOfCall(Future<void> Function() call) async {
    try {
      await call();
      return null;
    } on AuthError catch (e) {
      return e.failure;
    }
  }

  test('Demo login on: no SMS, ANY 6 digits, a normal session', () async {
    await service.sendCode(phone, language: 'fr', createAccount: true);
    await service.verifyCode(phone, '987654');
    expect(server.calls, [
      'demo-auth start',
      'demo-auth verify',
      'session from rt-demo', // the session of the Edge Function, renewed
    ]);
    expect(server.bodies[0], {
      'action': 'start',
      'phone': phone,
      'signUp': true,
    });
    expect(server.bodies[1], {
      'action': 'verify',
      'phone': phone,
      'code': '987654',
      'signUp': true,
      'language': 'fr',
    });
    expect(service.hasSession, isTrue);
    expect(supabase.auth.currentUser?.id, userId);
  });

  test('Demo login, sign in: the same, with signUp false', () async {
    await service.sendCode(phone, language: 'ar', createAccount: false);
    await service.verifyCode(phone, '000000');
    expect(server.bodies[0]['signUp'], isFalse);
    expect(server.bodies[1]['signUp'], isFalse);
    expect(service.hasSession, isTrue);
  });

  test('Demo login off (switch false): the SMS code of Supabase', () async {
    server.start = (200, {'demo': false});
    await service.sendCode(phone, language: 'ar', createAccount: true);
    await service.verifyCode(phone, '123456');
    expect(server.calls, ['demo-auth start', 'SMS code', 'check SMS code']);
    expect(service.hasSession, isTrue);
  });

  test('Edge Function not deployed (404): the SMS code of Supabase', () async {
    server.start = (404, {'code': 'NOT_FOUND'});
    await service.sendCode(phone, language: 'ar', createAccount: false);
    expect(server.calls, ['demo-auth start', 'SMS code']);
  });

  test('Sign in with a number without account: "no account", no SMS', () async {
    server.start = (200, {'error': 'no_account'});
    expect(
      await failureOfCall(
        () => service.sendCode(phone, language: 'ar', createAccount: false),
      ),
      AuthFailure.noAccount,
    );
    expect(server.calls, ['demo-auth start']);
  });

  test(
    '"Verify JWT" left on (401) or a server problem: "try again", no SMS',
    () async {
      for (final answer in [
        (401, {'msg': 'Invalid JWT'}),
        (500, {'error': 'server'}),
      ]) {
        server.calls.clear();
        server.start = answer;
        expect(
          await failureOfCall(
            () => service.sendCode(phone, language: 'ar', createAccount: true),
          ),
          AuthFailure.unknown,
          reason: '${answer.$1}',
        );
        expect(server.calls, ['demo-auth start']);
      }
    },
  );

  test('The answers at the code screen become the app\'s messages', () async {
    for (final (answer, failure) in [
      ((200, {'error': 'no_account'}), AuthFailure.noAccount),
      ((200, {'error': 'too_many'}), AuthFailure.tooManyTries),
      ((200, {'error': 'demo_off'}), AuthFailure.unknown),
      ((200, {'error': 'not_allowed'}), AuthFailure.unknown),
      ((400, {'error': 'bad_code'}), AuthFailure.wrongCode),
      ((500, {'error': 'server'}), AuthFailure.unknown),
      ((200, <String, Object?>{}), AuthFailure.unknown), // no session
    ]) {
      server.verify = answer;
      await service.sendCode(phone, language: 'ar', createAccount: true);
      expect(
        await failureOfCall(() => service.verifyCode(phone, '123456')),
        failure,
        reason: '$answer',
      );
      expect(service.hasSession, isFalse, reason: '$answer');
    }
  });

  test(
    'A code that is not 6 digits: refused before asking the server',
    () async {
      await service.sendCode(phone, language: 'ar', createAccount: true);
      server.calls.clear();
      expect(
        await failureOfCall(() => service.verifyCode(phone, '12345')),
        AuthFailure.wrongCode,
      );
      expect(server.calls, isEmpty);
    },
  );

  test('No internet: "no internet" (and no SMS)', () async {
    server.offline = true;
    expect(
      await failureOfCall(
        () => service.sendCode(phone, language: 'ar', createAccount: true),
      ),
      AuthFailure.noInternet,
    );
  });

  test('demoLoginFailure(): every answer of demo-auth', () {
    expect(demoLoginFailure({'error': 'no_account'}), AuthFailure.noAccount);
    expect(demoLoginFailure({'error': 'too_many'}), AuthFailure.tooManyTries);
    expect(demoLoginFailure({'error': 'bad_phone'}), AuthFailure.invalidPhone);
    expect(demoLoginFailure({'error': 'bad_code'}), AuthFailure.wrongCode);
    for (final other in ['demo_off', 'not_allowed', 'server', 'x']) {
      expect(demoLoginFailure({'error': other}), AuthFailure.unknown);
    }
    expect(demoLoginFailure('not json'), AuthFailure.unknown);
    expect(demoLoginFailure(null), AuthFailure.unknown);
  });
}
