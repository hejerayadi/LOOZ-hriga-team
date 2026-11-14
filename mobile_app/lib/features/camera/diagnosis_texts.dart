// The texts of the photo diagnosis that depend on the codes of the model:
// the name of each disease, "على الأرجح" / "غير متأكد", the first steps
// (DRAFTS to validate by an agronomist: no pesticide names, no doses), and
// the messages of each failure.
import '../../core/locale.dart';
import '../../data/diagnosis_service.dart';

String diseaseName(AppLocalizations l10n, Disease disease) => switch (disease) {
  Disease.shotHole => l10n.diseaseShotHole,
  Disease.leafCurl => l10n.diseaseLeafCurl,
  Disease.leafSpot => l10n.diseaseLeafSpot,
};

/// "على الأرجح" / "غير متأكد" (never "متأكد": it is not a final diagnosis).
String certaintyWord(AppLocalizations l10n, Verdict verdict) =>
    verdict == Verdict.likely ? l10n.verdictLikely : l10n.verdictUnsure;

/// The 2-3 first steps of a disease (DRAFT, see the ARB notes).
List<String> firstSteps(AppLocalizations l10n, Disease disease) =>
    switch (disease) {
      Disease.shotHole => [
        l10n.adviceShotHole1,
        l10n.adviceShotHole2,
        l10n.adviceShotHole3,
      ],
      Disease.leafCurl => [
        l10n.adviceLeafCurl1,
        l10n.adviceLeafCurl2,
        l10n.adviceLeafCurl3,
      ],
      Disease.leafSpot => [
        l10n.adviceLeafSpot1,
        l10n.adviceLeafSpot2,
        l10n.adviceLeafSpot3,
      ],
    };

/// The community question of "اسأل خبيرًا" (the farmer can change it).
String expertQuestion(AppLocalizations l10n, Diagnosis diagnosis) {
  final disease = diagnosis.disease;
  if (diagnosis.verdict == Verdict.nothing || disease == null) {
    return l10n.expertQuestionNothing;
  }
  return l10n.expertQuestionFound(
    diseaseName(l10n, disease),
    certaintyWord(l10n, diagnosis.verdict),
  );
}

/// The message of a failure ([perDay] for the limit of the day).
String diagnosisFailureMessage(
  AppLocalizations l10n,
  DiagnosisFailure failure, {
  int? perDay,
}) => switch (failure) {
  DiagnosisFailure.noInternet => l10n.needInternet,
  DiagnosisFailure.limitDay => l10n.limitReached(perDay ?? 10),
  DiagnosisFailure.busy => l10n.diagnosisBusy,
  DiagnosisFailure.unavailable ||
  DiagnosisFailure.notPaid => l10n.diagnosisUnavailable,
  DiagnosisFailure.badImage => l10n.photoUnreadable,
  DiagnosisFailure.sessionExpired => l10n.errorSessionExpired,
  DiagnosisFailure.unknown => l10n.somethingWrong,
};
