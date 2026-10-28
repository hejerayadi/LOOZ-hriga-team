// Sign up / sign in with the phone number (Supabase Auth + table "profiles").
//
// The app only uses the publishable ("anon") key: what a user may read or
// change is decided by the database rules (RLS, migration 005), not here.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/plans.dart';
import '../core/validators.dart';
import 'user_profile.dart';

/// Why a step failed. Each one has a message in Arabic and French
/// (see failureMessage() in lib/features/onboarding/auth_messages.dart).
enum AuthFailure {
  noInternet,
  wrongCode, // wrong or expired code (Supabase does not tell which)
  tooManyTries,
  cannotReceiveCode, // e.g. a real number while only test numbers work
  invalidPhone,
  phoneTaken,
  invalidName,
  sessionExpired,
  unknown,
}

/// The error thrown by every AuthService method.
class AuthError implements Exception {
  const AuthError(this.failure, [this.cause]);

  final AuthFailure failure;

  /// The original error (for the developer).
  final Object? cause;

  @override
  String toString() => 'AuthError(${failure.name}, $cause)';
}

/// What the app needs from the login system. The app uses
/// SupabaseAuthService; the tests use a fake one (no internet needed).
abstract class AuthService {
  /// true when a user is logged in (also after the app was closed).
  bool get hasSession;

  /// Sends the code by SMS to [phone] ("+21698123456"). Creates the account
  /// if the number is new, with the [language] chosen on the first screen.
  Future<void> sendCode(String phone, {required String language});

  /// Checks the code: the user is logged in after it.
  Future<void> verifyCode(String phone, String code);

  /// The profile of the logged-in user.
  Future<UserProfile> loadProfile();

  Future<UserProfile> saveName(String firstName, String lastName);

  Future<UserProfile> saveLanguage(String language);

  /// Saves the pack chosen at sign-up. A paid pack is saved as "pending":
  /// the user keeps the free plan until it is paid.
  Future<UserProfile> choosePlan(Plan plan);

  /// The plan the user really has now (free until a pack is paid).
  Future<Plan> loadPlan();

  /// Logs out: the session is forgotten on this phone.
  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  /// Longest wait for an answer of the server.
  static const timeout = Duration(seconds: 20);

  @override
  bool get hasSession => _client.auth.currentSession != null;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthError(AuthFailure.sessionExpired);
    return id;
  }

  @override
  Future<void> sendCode(String phone, {required String language}) => _run(() {
    if (!isValidPhone(phone)) throw const AuthError(AuthFailure.invalidPhone);
    return _client.auth.signInWithOtp(
      phone: phone,
      shouldCreateUser: true,
      data: {'language': language},
    );
  });

  @override
  Future<void> verifyCode(String phone, String code) => _run(() async {
    if (!isValidCode(code)) throw const AuthError(AuthFailure.wrongCode);
    await _client.auth.verifyOTP(
      phone: phone,
      token: code,
      type: OtpType.sms,
    );
  });

  @override
  Future<UserProfile> loadProfile() => _run(() async {
    final row = await _client
        .from('profiles')
        .select(UserProfile.columns)
        .eq('id', _userId)
        .maybeSingle();
    if (row == null) throw const AuthError(AuthFailure.unknown);
    return UserProfile.fromRow(row);
  });

  @override
  Future<UserProfile> saveName(String firstName, String lastName) =>
      _run(() async {
        if (checkName(firstName) != null || checkName(lastName) != null) {
          throw const AuthError(AuthFailure.invalidName);
        }
        return _update({
          'first_name': cleanName(firstName),
          'last_name': cleanName(lastName),
        });
      });

  @override
  Future<UserProfile> saveLanguage(String language) =>
      _run(() => _update({'language': language == 'fr' ? 'fr' : 'ar'}));

  @override
  Future<UserProfile> choosePlan(Plan plan) => _run(() async {
    // The only way to save the pack (the app cannot write "paid").
    await _client.rpc('choose_plan', params: {'p_plan': plan.name});
    return loadProfile();
  });

  @override
  Future<Plan> loadPlan() => _run(() async {
    final name = await _client.rpc('user_plan');
    return Plan.values.firstWhere((p) => p.name == name, orElse: () => Plan.free);
  });

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Without internet the server is not told, but the session is
      // already forgotten on the phone: the user is logged out.
    }
  }

  Future<UserProfile> _update(Map<String, Object> values) async {
    final row = await _client
        .from('profiles')
        .update(values)
        .eq('id', _userId)
        .select(UserProfile.columns)
        .single();
    return UserProfile.fromRow(row);
  }

  /// Runs a call to the server: too slow = no internet, and every error
  /// becomes an AuthError.
  Future<T> _run<T>(FutureOr<T> Function() call) async {
    try {
      return await Future.sync(call).timeout(timeout);
    } on AuthError {
      rethrow;
    } catch (error) {
      throw AuthError(failureOf(error), error);
    }
  }
}

/// Turns an error of Supabase into an AuthFailure.
/// Codes: https://supabase.com/docs/guides/auth/debugging/error-codes
AuthFailure failureOf(Object error) {
  if (error is AuthError) return error.failure;
  if (error is TimeoutException || _isNetworkError(error)) {
    return AuthFailure.noInternet;
  }
  if (error is AuthSessionMissingException) return AuthFailure.sessionExpired;
  if (error is AuthRetryableFetchException) {
    // No answer at all = no internet. Server errors (500...) keep their
    // code in the message.
    if (error.statusCode == null) return AuthFailure.noInternet;
    if (error.message.contains('sms_send_failed') ||
        error.message.contains('Error sending')) {
      return AuthFailure.cannotReceiveCode;
    }
    return AuthFailure.unknown;
  }
  if (error is AuthException) {
    switch (error.code) {
      case 'otp_expired':
        return AuthFailure.wrongCode;
      case 'over_sms_send_rate_limit':
      case 'over_request_rate_limit':
        return AuthFailure.tooManyTries;
      case 'phone_provider_disabled': // only test numbers are set up
      case 'sms_send_failed':
        return AuthFailure.cannotReceiveCode;
      case 'validation_failed':
        return AuthFailure.invalidPhone;
      case 'phone_exists':
        return AuthFailure.phoneTaken;
      case 'session_not_found':
      case 'session_expired':
      case 'refresh_token_not_found':
      case 'refresh_token_already_used':
      case 'user_not_found':
      case 'bad_jwt':
        return AuthFailure.sessionExpired;
    }
    if (error.statusCode == '429') return AuthFailure.tooManyTries;
    return AuthFailure.unknown;
  }
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == '23505') return AuthFailure.phoneTaken; // same phone twice
    if (code == '23514') return AuthFailure.invalidName; // database check
    if (code.startsWith('PGRST30')) return AuthFailure.sessionExpired; // JWT
    return AuthFailure.unknown;
  }
  return AuthFailure.unknown;
}

/// No connection (the type of error differs between phones and the web).
bool _isNetworkError(Object error) {
  final text = error.toString();
  return const [
    'SocketException',
    'ClientException',
    'Failed host lookup',
    'Connection refused',
    'Connection reset',
    'Network is unreachable',
    'XMLHttpRequest error',
  ].any(text.contains);
}
