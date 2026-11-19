// The VOICE ASSISTANT "لوز" (Bêta, paid pack). The Edge Function
// "voice-token" (supabase/functions/voice-token) checks the paid pack, the
// farmer's "yes" to the voice message and his minutes of the day, and gives
// a short-lived token of Google (Gemini Live), LOCKED to the instructions and
// the tools of "لوز" (migration 017). The app then talks directly to Google
// (gemini_live.dart). Nothing of the voice or of the words is saved: only how
// long, how many questions and how many tool calls.
//
// The screens only know VoiceService (the tests put a fake one).
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import 'auth_service.dart';

/// Before the microphone (my_voice_quota()).
class VoiceQuota {
  const VoiceQuota({
    required this.enabled,
    required this.paid,
    required this.consent,
    required this.perDaySeconds,
    required this.leftSeconds,
    required this.sessionSeconds,
    required this.appOpen,
    this.googleFreeTier = true,
  });

  final bool enabled;
  final bool paid;

  /// The farmer said "موافق" to "your voice goes to Google".
  final bool consent;
  final int perDaySeconds;
  final int leftSeconds;

  /// The longest conversation.
  final int sessionSeconds;

  /// false = the whole app used its minutes of the day.
  final bool appOpen;

  /// The Gemini key is on Google's free tier: the first-time message says
  /// Google may use the voice to improve its products.
  final bool googleFreeTier;

  /// A conversation needs 30 seconds at least (like voice_begin).
  bool get canTalk => leftSeconds >= minSeconds;

  static const minSeconds = 30;

  static VoiceQuota fromRow(Map<String, dynamic> row) => VoiceQuota(
    enabled: row['enabled'] as bool? ?? false,
    paid: row['paid'] as bool? ?? false,
    consent: row['consent'] as bool? ?? false,
    perDaySeconds: (row['per_day_seconds'] as num?)?.toInt() ?? 0,
    leftSeconds: (row['left_seconds'] as num?)?.toInt() ?? 0,
    sessionSeconds: (row['session_seconds'] as num?)?.toInt() ?? 0,
    appOpen: row['app_open'] as bool? ?? false,
    googleFreeTier: row['google_free_tier'] as bool? ?? true,
  );
}

/// One conversation opened by "voice-token": Google's token and its length.
class VoiceTicket {
  const VoiceTicket({
    required this.id,
    required this.token,
    required this.model,
    required this.seconds,
    required this.leftSeconds,
  });

  final String id;

  /// Google's short-lived, single-use token (never saved).
  final String token;
  final String model;

  /// Length of this conversation.
  final int seconds;

  /// Seconds left today after this conversation.
  final int leftSeconds;

  static VoiceTicket fromAnswer(Map<String, dynamic> a) => VoiceTicket(
    id: a['id'] as String,
    token: a['token'] as String,
    model: a['model'] as String? ?? 'gemini-3.8-live',
    seconds: (a['seconds'] as num?)?.toInt() ?? 0,
    leftSeconds: (a['left_seconds'] as num?)?.toInt() ?? 0,
  );
}

/// Why the assistant can't talk (each one has a message in Arabic and French).
enum VoiceFailure {
  noInternet, // "تحتاج إلى الإنترنت"
  notPaid, // the paid pack ended: the locked screen
  consent, // the first-time message (not an error)
  limitDay, // the farmer's minutes of the day are used
  busy, // the minutes of the whole app are used
  off, // switched off by an admin
  unavailable, // Google or the function did not answer
  micDenied, // the microphone is not allowed
  sessionExpired,
  unknown,
}

class VoiceError implements Exception {
  const VoiceError(this.failure, {this.cause});

  final VoiceFailure failure;
  final Object? cause;

  @override
  String toString() => 'VoiceError(${failure.name}, $cause)';
}

/// How a conversation ended (voice_end): the stop button or the screen
/// closed, its time was over, or the connection broke.
enum VoiceEndReason {
  farmer('farmer'),
  timeUp('time_up'),
  error('error');

  const VoiceEndReason(this.code);

  final String code;
}

/// The counts of a conversation (statistics only: no words).
class VoiceUsage {
  int questions = 0;
  int toolCalls = 0;
  int posts = 0;
  int? tokensIn;
  int? tokensOut;
}

abstract class VoiceService {
  /// Is it on, did he say yes, how many seconds are left today.
  Future<VoiceQuota> loadQuota();

  /// "موافق" (true) on the first-time message, or take it back (false).
  Future<void> setConsent(bool yes);

  /// Opens a conversation: Google's token ([language] = the app's).
  Future<VoiceTicket> start(String language);

  /// Ends it (the database measures the time). Returns the seconds left
  /// today (null = not known: no internet...). Never throws.
  Future<int?> end(String id, VoiceEndReason reason, VoiceUsage usage);
}

VoiceService? _voiceService;

/// The assistant: Supabase in the app (the tests put a fake one).
VoiceService get voiceService =>
    _voiceService ??= SupabaseVoiceService(supabase);
set voiceService(VoiceService service) => _voiceService = service;

class SupabaseVoiceService implements VoiceService {
  SupabaseVoiceService(this._client);

  final SupabaseClient _client;

  /// The name of the Edge Function.
  static const function = 'voice-token';

  /// Google is tried twice (10 s each) at most.
  static const timeout = Duration(seconds: 30);

  @override
  Future<VoiceQuota> loadQuota() async {
    try {
      final row = await _client
          .rpc('my_voice_quota')
          .timeout(const Duration(seconds: 20));
      if (row is! Map) throw const VoiceError(VoiceFailure.sessionExpired);
      return VoiceQuota.fromRow(Map<String, dynamic>.from(row));
    } catch (error) {
      throw VoiceError(voiceFailureOf(error), cause: error);
    }
  }

  @override
  Future<void> setConsent(bool yes) async {
    try {
      await _client
          .rpc('voice_set_consent', params: {'p_on': yes})
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      throw VoiceError(voiceFailureOf(error), cause: error);
    }
  }

  @override
  Future<VoiceTicket> start(String language) async {
    final FunctionResponse response;
    try {
      response = await _client.functions
          .invoke(function, body: {'lang': language})
          .timeout(timeout);
    } on FunctionsFetchException catch (error) {
      throw VoiceError(VoiceFailure.noInternet, cause: error);
    } on FunctionException catch (error) {
      throw VoiceError(
        error.status == 401
            ? VoiceFailure.sessionExpired
            : VoiceFailure.unavailable, // 404 (not deployed), 500...
        cause: error,
      );
    } catch (error) {
      throw VoiceError(voiceFailureOf(error), cause: error);
    }
    final data = response.data;
    if (data is! Map) throw const VoiceError(VoiceFailure.unavailable);
    final answer = Map<String, dynamic>.from(data);
    final code = answer['error'];
    if (code != null) throw VoiceError(voiceFailureOfCode('$code'));
    if (answer['token'] is! String || answer['id'] is! String) {
      throw const VoiceError(VoiceFailure.unavailable);
    }
    return VoiceTicket.fromAnswer(answer);
  }

  @override
  Future<int?> end(String id, VoiceEndReason reason, VoiceUsage usage) async {
    try {
      final row = await _client
          .rpc(
            'voice_end',
            params: {
              'p_id': id,
              'p_reason': reason.code,
              'p_questions': usage.questions,
              'p_tool_calls': usage.toolCalls,
              'p_posts': usage.posts,
              'p_tokens_in': usage.tokensIn,
              'p_tokens_out': usage.tokensOut,
            },
          )
          .timeout(const Duration(seconds: 20));
      return row is Map ? (row['left_seconds'] as num?)?.toInt() : null;
    } catch (_) {
      // Not ended here = ended by the database later ("lost", its whole
      // length counted). Nothing to show to the farmer.
      return null;
    }
  }
}

/// The error codes of the Edge Function.
VoiceFailure voiceFailureOfCode(String code) => switch (code) {
  'not_logged_in' => VoiceFailure.sessionExpired,
  'not_paid' => VoiceFailure.notPaid,
  'consent' => VoiceFailure.consent,
  'limit_day' => VoiceFailure.limitDay,
  'busy' => VoiceFailure.busy,
  'off' => VoiceFailure.off,
  'unavailable' || 'server' => VoiceFailure.unavailable,
  _ => VoiceFailure.unknown,
};

/// Any other error (no internet, session...).
VoiceFailure voiceFailureOf(Object error) {
  if (error is VoiceError) return error.failure;
  if (error is PostgrestException) {
    if ((error.code ?? '').startsWith('PGRST30') || error.code == '42501') {
      return VoiceFailure.sessionExpired;
    }
    return VoiceFailure.unknown;
  }
  switch (failureOf(error)) {
    case AuthFailure.noInternet:
      return VoiceFailure.noInternet;
    case AuthFailure.sessionExpired:
      return VoiceFailure.sessionExpired;
    default:
      return VoiceFailure.unknown;
  }
}
