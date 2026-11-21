// The PHOTO DIAGNOSIS (Bêta, paid pack): the photo of an almond leaf goes to
// the Edge Function "diagnose" (supabase/functions/diagnose), which asks the
// model (Gemini or Roboflow: app_settings.diagnosis_model) and saves the
// result (migrations 016 and 018). It answers with CODES only: the screens
// write the texts in Arabic or French.
//
// The screens only know DiagnosisService: another model (on the phone,
// later) is another class with the same methods, the screens don't change.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import 'auth_service.dart';
import 'community_photos.dart';

/// The 3 diseases the model knows (there is no "healthy").
enum Disease { shotHole, leafCurl, leafSpot }

/// likely = "على الأرجح", unsure = "غير متأكد", nothing = "لم نجد…".
/// The database decides it with its thresholds (app_settings).
enum Verdict { likely, unsure, nothing }

class Diagnosis {
  const Diagnosis({
    required this.id,
    required this.verdict,
    required this.createdAt,
    this.disease,
    this.confidence,
    this.marked = const [],
    this.photoPath,
    this.usedToday,
    this.perDay,
  });

  final String id;
  final Verdict verdict;

  /// null when nothing was found.
  final Disease? disease;
  final double? confidence;

  /// The sick spots to mark on the photo: fractions of its width / height.
  final List<Rect> marked;

  /// In the private bucket "diagnoses" (null = deleted, old).
  final String? photoPath;
  final DateTime createdAt;

  /// Photos sent today and allowed per day (after this one).
  final int? usedToday;
  final int? perDay;

  static const _codes = {
    'shot_hole': Disease.shotHole,
    'leaf_curl': Disease.leafCurl,
    'leaf_spot': Disease.leafSpot,
  };

  /// The answer of the Edge Function.
  static Diagnosis fromAnswer(Map<String, dynamic> a) {
    final verdict = Verdict.values.firstWhere(
      (v) => v.name == a['verdict'],
      orElse: () => Verdict.nothing,
    );
    final disease = _codes[a['top_class']];
    return Diagnosis(
      id: a['id'] as String,
      // A verdict without a known disease is "nothing" (never a guess).
      verdict: disease == null ? Verdict.nothing : verdict,
      disease: disease,
      confidence: (a['top_confidence'] as num?)?.toDouble(),
      marked: [
        for (final box in (a['marked'] as List? ?? const []))
          if (box is List && box.length == 4)
            Rect.fromLTRB(
              (box[0] as num).toDouble(),
              (box[1] as num).toDouble(),
              (box[2] as num).toDouble(),
              (box[3] as num).toDouble(),
            ),
      ],
      photoPath: a['photo_path'] as String?,
      createdAt:
          DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime.now(),
      usedToday: (a['used_today'] as num?)?.toInt(),
      perDay: (a['per_day'] as num?)?.toInt(),
    );
  }
}

/// How many photos are left today (my_diagnosis_quota()), and where the
/// photo goes (the camera screen says it).
class DiagnosisQuota {
  const DiagnosisQuota({
    required this.enabled,
    required this.paid,
    required this.perDay,
    required this.usedToday,
    this.google = false,
    this.googleFreeTier = false,
  });

  final bool enabled;
  final bool paid;
  final int perDay;
  final int usedToday;

  /// The photo is examined by Google (Gemini): app_settings.diagnosis_model.
  final bool google;

  /// Google's free tier: Google may use the photo to improve its services.
  final bool googleFreeTier;

  int get left => (perDay - usedToday).clamp(0, perDay);

  static DiagnosisQuota fromRow(Map<String, dynamic> row) => DiagnosisQuota(
    enabled: row['enabled'] as bool? ?? false,
    paid: row['paid'] as bool? ?? false,
    perDay: (row['per_day'] as num?)?.toInt() ?? 0,
    usedToday: (row['used_today'] as num?)?.toInt() ?? 0,
    // Before migration 018 the database doesn't say it: Roboflow.
    google: row['google'] as bool? ?? false,
    googleFreeTier: row['google_free_tier'] as bool? ?? false,
  );
}

/// Why a diagnosis failed (each one has a message in Arabic and French).
enum DiagnosisFailure {
  noInternet, // "تحتاج إلى الإنترنت"
  notPaid, // the paid pack ended: the locked screen
  limitDay, // "وصلت إلى 10 صور اليوم"
  busy, // the app's limit of the day, Google busy or its limits, no credits
  unavailable, // switched off, the model or the storage failed
  badImage, // not a photo that can be read
  sessionExpired,
  unknown,
}

class DiagnosisError implements Exception {
  const DiagnosisError(this.failure, {this.perDay, this.cause});

  final DiagnosisFailure failure;

  /// For "وصلت إلى {n} صور اليوم".
  final int? perDay;
  final Object? cause;

  @override
  String toString() => 'DiagnosisError(${failure.name}, $cause)';
}

abstract class DiagnosisService {
  /// Is it on, and how many photos are left today.
  Future<DiagnosisQuota> loadQuota();

  /// Sends the photo (already small and without GPS) and waits for the result.
  Future<Diagnosis> diagnose(PreparedPhoto photo);

  /// "اسأل خبيرًا": the community question made from this diagnosis.
  Future<void> linkPost(String diagnosisId, String postId);
}

DiagnosisService? _diagnosisService;

/// The diagnosis: Supabase in the app (the tests put a fake one).
DiagnosisService get diagnosisService =>
    _diagnosisService ??= SupabaseDiagnosisService(supabase);
set diagnosisService(DiagnosisService service) => _diagnosisService = service;

class SupabaseDiagnosisService implements DiagnosisService {
  SupabaseDiagnosisService(this._client);

  final SupabaseClient _client;

  /// The name of the Edge Function.
  static const function = 'diagnose';

  /// The model may wake up slowly (and is tried twice): wait long enough.
  static const timeout = Duration(seconds: 70);

  @override
  Future<DiagnosisQuota> loadQuota() async {
    try {
      final row = await _client
          .rpc('my_diagnosis_quota')
          .timeout(const Duration(seconds: 20));
      return DiagnosisQuota.fromRow(Map<String, dynamic>.from(row as Map));
    } catch (error) {
      throw DiagnosisError(diagnosisFailureOf(error), cause: error);
    }
  }

  @override
  Future<Diagnosis> diagnose(PreparedPhoto photo) async {
    final FunctionResponse response;
    try {
      response = await _client.functions
          .invoke(function, body: {'image': base64Encode(photo.bytes)})
          .timeout(timeout);
    } on FunctionsFetchException catch (error) {
      // No answer at all.
      throw DiagnosisError(DiagnosisFailure.noInternet, cause: error);
    } on FunctionException catch (error) {
      throw DiagnosisError(switch (error.status) {
        401 => DiagnosisFailure.sessionExpired,
        400 => DiagnosisFailure.badImage,
        _ => DiagnosisFailure.unavailable, // 404 (not deployed), 500...
      }, cause: error);
    } catch (error) {
      throw DiagnosisError(diagnosisFailureOf(error), cause: error);
    }
    final data = response.data;
    if (data is! Map) {
      throw const DiagnosisError(DiagnosisFailure.unavailable);
    }
    final answer = Map<String, dynamic>.from(data);
    final code = answer['error'];
    if (code != null) {
      throw DiagnosisError(
        failureOfCode(code as String),
        perDay: (answer['per_day'] as num?)?.toInt(),
      );
    }
    return Diagnosis.fromAnswer(answer);
  }

  @override
  Future<void> linkPost(String diagnosisId, String postId) async {
    try {
      await _client
          .rpc(
            'diagnosis_link_post',
            params: {'p_diagnosis': diagnosisId, 'p_post': postId},
          )
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      throw DiagnosisError(diagnosisFailureOf(error), cause: error);
    }
  }
}

/// The error codes of the Edge Function.
DiagnosisFailure failureOfCode(String code) => switch (code) {
  'not_logged_in' => DiagnosisFailure.sessionExpired,
  'not_paid' => DiagnosisFailure.notPaid,
  'limit_day' => DiagnosisFailure.limitDay,
  'busy' => DiagnosisFailure.busy,
  'off' || 'unavailable' => DiagnosisFailure.unavailable,
  'bad_image' => DiagnosisFailure.badImage,
  _ => DiagnosisFailure.unknown,
};

/// Any other error (no internet, session...).
DiagnosisFailure diagnosisFailureOf(Object error) {
  if (error is DiagnosisError) return error.failure;
  if (error is PostgrestException) {
    if ((error.code ?? '').startsWith('PGRST30')) {
      return DiagnosisFailure.sessionExpired;
    }
    return DiagnosisFailure.unknown;
  }
  switch (failureOf(error)) {
    case AuthFailure.noInternet:
      return DiagnosisFailure.noInternet;
    case AuthFailure.sessionExpired:
      return DiagnosisFailure.sessionExpired;
    default:
      return DiagnosisFailure.unknown;
  }
}
