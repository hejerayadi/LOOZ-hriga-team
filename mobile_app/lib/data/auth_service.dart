// Sign up / sign in with the phone number (Supabase Auth + table "profiles").
//
// The app only uses the publishable ("anon") key: what a user may read or
// change is decided by the database rules (RLS, migration 005), not here.
//
// DEMO LOGIN (migration 010 + Edge Function "demo-auth"): while
// app_settings.demo_login_enabled = true, any +216 number and any 6-digit
// code log in, no SMS. The Edge Function makes the session (it alone has the
// service_role key). Switch off: the normal SMS code of Supabase.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/governorates.dart';
import '../core/plans.dart';
import '../core/validators.dart';
import 'user_profile.dart';

/// Why a step failed. Each one has a message in Arabic and French
/// (see failureMessage() in lib/features/onboarding/auth_messages.dart).
enum AuthFailure {
  noInternet,
  noAccount, // sign in with a number that has no account
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

/// What the user gives at the step "your information" of the sign-up.
class SignUpInfo {
  const SignUpInfo({
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.governorate,
    this.almondTrees,
    this.orchardAreaHa,
    this.irrigation,
    this.organisation,
  });

  /// farmer or expert.
  final UserRole role;
  final String firstName;
  final String lastName;

  /// One of the 24 codes of core/governorates.dart.
  final String governorate;

  /// Optional.
  final int? almondTrees;
  final double? orchardAreaHa;
  final Irrigation? irrigation;

  /// Experts only, optional.
  final String? organisation;
}

/// What the app needs from the login system. The app uses
/// SupabaseAuthService; the tests use a fake one (no internet needed).
abstract class AuthService {
  /// true when a user is logged in (also after the app was closed).
  bool get hasSession;

  /// Sends the code by SMS to [phone] ("+21698123456").
  /// Sign up ([createAccount] true): creates the account if the number is
  /// new, with the [language] chosen on the first screen. Sign in (false):
  /// a number without account is refused (AuthFailure.noAccount).
  /// Demo login on: no SMS is sent, and any 6-digit code will work.
  Future<void> sendCode(
    String phone, {
    required String language,
    required bool createAccount,
  });

  /// Checks the code: the user is logged in after it.
  Future<void> verifyCode(String phone, String code);

  /// The profile of the logged-in user.
  Future<UserProfile> loadProfile();

  /// Saves the step "your information" of the sign-up (the role can only
  /// be chosen before the pack).
  Future<UserProfile> saveSignUpInfo(SignUpInfo info);

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

  /// The number waiting for its code when the demo login is on (no SMS was
  /// sent): its code is checked by the Edge Function.
  ({String phone, bool signUp, String language})? _demo;

  @override
  Future<void> sendCode(
    String phone, {
    required String language,
    required bool createAccount,
  }) => _run(() async {
    if (!isValidPhone(phone)) throw const AuthError(AuthFailure.invalidPhone);
    _demo = null;
    final demo = await _demoAuth({
      'action': 'start',
      'phone': phone,
      'signUp': createAccount,
    });
    if (demo?['demo'] == true) {
      _demo = (phone: phone, signUp: createAccount, language: language);
      return;
    }
    await _client.auth.signInWithOtp(
      phone: phone,
      shouldCreateUser: createAccount,
      data: createAccount ? {'language': language} : null,
    );
  });

  @override
  Future<void> verifyCode(String phone, String code) => _run(() async {
    if (!isValidCode(code)) throw const AuthError(AuthFailure.wrongCode);
    final demo = _demo;
    if (demo == null || demo.phone != phone) {
      await _client.auth.verifyOTP(
        phone: phone,
        token: code,
        type: OtpType.sms,
      );
      return;
    }
    // Demo login: any code; a new number + sign up = a new account.
    final answer = await _demoAuth({
      'action': 'verify',
      'phone': phone,
      'code': code,
      'signUp': demo.signUp,
      'language': demo.language,
    });
    final refreshToken = answer?['refresh_token'];
    if (refreshToken is! String) throw const AuthError(AuthFailure.unknown);
    // The session is kept on the phone, like after an SMS code.
    await _client.auth.setSession(refreshToken);
    _demo = null;
  });

  /// Calls the Edge Function "demo-auth". null = it is not deployed (then
  /// the normal SMS code is used). Its errors become AuthErrors.
  Future<Map<String, dynamic>?> _demoAuth(Map<String, Object?> body) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(demoAuthFunction, body: body);
    } on FunctionsFetchException catch (e) {
      // No answer at all.
      throw AuthError(AuthFailure.noInternet, e);
    } on FunctionException catch (e) {
      if (e.status == 404) return null;
      throw AuthError(demoLoginFailure(e.details), e);
    }
    final data = response.data;
    if (data is! Map) throw const AuthError(AuthFailure.unknown);
    if (data['error'] != null) throw AuthError(demoLoginFailure(data));
    return data.cast<String, dynamic>();
  }

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
  Future<UserProfile> saveSignUpInfo(SignUpInfo info) => _run(() async {
    if (checkName(info.firstName) != null || checkName(info.lastName) != null) {
      throw const AuthError(AuthFailure.invalidName);
    }
    if (!governorates.contains(info.governorate)) {
      throw const AuthError(AuthFailure.unknown);
    }
    // The role: the only way to save it (never "admin", never "verified").
    await _client.rpc(
      'choose_role',
      params: {'p_role': info.role.name, 'p_organisation': info.organisation},
    );
    return _update({
      'first_name': cleanName(info.firstName),
      'last_name': cleanName(info.lastName),
      'zone': info.governorate,
      'almond_trees': info.almondTrees,
      'orchard_area_ha': info.orchardAreaHa,
      'irrigation': info.irrigation?.name,
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
    return Plan.values.firstWhere(
      (p) => p.name == name,
      orElse: () => Plan.free,
    );
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

  Future<UserProfile> _update(Map<String, Object?> values) async {
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

/// The Edge Function of the demo login (supabase/functions/demo-auth).
const demoAuthFunction = 'demo-auth';

/// Turns an answer of "demo-auth" ({"error": "no_account"}...) into an
/// AuthFailure. "demo_off" (switched off between the two screens),
/// "not_allowed" (an admin) and "server": unknown ("try again").
AuthFailure demoLoginFailure(Object? answer) =>
    switch (answer is Map ? answer['error'] : null) {
      'no_account' => AuthFailure.noAccount,
      'too_many' => AuthFailure.tooManyTries,
      'bad_phone' => AuthFailure.invalidPhone,
      'bad_code' => AuthFailure.wrongCode,
      _ => AuthFailure.unknown,
    };

/// Turns an error of Supabase into an AuthFailure.
/// Codes: https://supabase.com/docs/guides/auth/debugging/error-codes
AuthFailure failureOf(Object error) {
  if (error is AuthError) return error.failure;
  if (error is TimeoutException || isNetworkError(error)) {
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
      case 'otp_disabled': // "Signups not allowed for otp": sign in, no account
        return AuthFailure.noAccount;
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
/// Also used by the community (community_service.dart).
bool isNetworkError(Object error) {
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
