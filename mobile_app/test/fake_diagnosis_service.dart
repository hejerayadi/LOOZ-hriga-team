// A fake photo diagnosis for the tests (no internet, no model): it answers
// like the Edge Function "diagnose" (codes only), or fails on demand.
import 'dart:async';
import 'dart:ui' show Rect;

import 'package:looz_mobile/data/community_photos.dart';
import 'package:looz_mobile/data/diagnosis_service.dart';

class FakeDiagnosisService implements DiagnosisService {
  FakeDiagnosisService([Diagnosis? result]) : result = result ?? sampleSick();

  /// The answer of the next diagnoses.
  Diagnosis result;

  /// Before the camera: 10 a day, 3 used.
  DiagnosisQuota quota = const DiagnosisQuota(
    enabled: true,
    paid: true,
    perDay: 10,
    usedToday: 3,
  );

  /// The next diagnosis fails with this error (once).
  DiagnosisError? failNext;

  /// Every call fails with "no internet".
  bool offline = false;

  /// Not null = the diagnosis waits for it (to see "جاري النظر…").
  Completer<void>? hold;

  /// "quota", "diagnose 1234" (the size of the photo), "link d-sick p9".
  final List<String> calls = [];

  /// diagnosis id -> post id ("اسأل خبيرًا").
  final Map<String, String> linked = {};

  @override
  Future<DiagnosisQuota> loadQuota() async {
    calls.add('quota');
    if (offline) throw const DiagnosisError(DiagnosisFailure.noInternet);
    return quota;
  }

  @override
  Future<Diagnosis> diagnose(PreparedPhoto photo) async {
    calls.add('diagnose ${photo.bytes.length}');
    await hold?.future;
    if (offline) throw const DiagnosisError(DiagnosisFailure.noInternet);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return result;
  }

  @override
  Future<void> linkPost(String diagnosisId, String postId) async {
    calls.add('link $diagnosisId $postId');
    linked[diagnosisId] = postId;
  }
}

/// Shot hole, probably (0.82), 2 spots marked.
Diagnosis sampleSick() => Diagnosis(
  id: 'd-sick',
  verdict: Verdict.likely,
  disease: Disease.shotHole,
  confidence: 0.82,
  marked: const [
    Rect.fromLTRB(0.1, 0.2, 0.3, 0.4),
    Rect.fromLTRB(0.55, 0.6, 0.7, 0.75),
  ],
  createdAt: DateTime(2026, 11, 14, 10),
  photoPath: 'u/d-sick.jpg',
  usedToday: 4,
  perDay: 10,
);

/// Leaf curl, not sure (0.50).
Diagnosis sampleUnsure() => Diagnosis(
  id: 'd-unsure',
  verdict: Verdict.unsure,
  disease: Disease.leafCurl,
  confidence: 0.5,
  marked: const [Rect.fromLTRB(0.2, 0.2, 0.8, 0.8)],
  createdAt: DateTime(2026, 11, 14, 10),
);

/// Nothing found.
Diagnosis sampleNothing() => Diagnosis(
  id: 'd-nothing',
  verdict: Verdict.nothing,
  createdAt: DateTime(2026, 11, 14, 10),
);
