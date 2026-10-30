// The texts of the community that depend on the data: the error messages,
// the regions, "منذ ساعتين", the line under a question...
import '../../core/locale.dart';
import '../../core/validators.dart';
import '../../data/community_models.dart';
import '../../data/community_service.dart';

/// The text of an error, in the language of the app.
String communityFailureMessage(
  AppLocalizations l10n,
  CommunityFailure failure,
) {
  switch (failure) {
    case CommunityFailure.noInternet:
      return l10n.errorNoInternet;
    case CommunityFailure.tooFast:
      return l10n.tooFast;
    case CommunityFailure.postGone:
      return l10n.postGone;
    case CommunityFailure.notAllowed:
      return l10n.cantDelete;
    case CommunityFailure.sessionExpired:
      return l10n.errorSessionExpired;
    case CommunityFailure.photoTooBig:
      return l10n.photoTooBig;
    case CommunityFailure.photoWrongType:
      return l10n.photoWrongType;
    case CommunityFailure.uploadFailed:
      return l10n.uploadFailed;
    case CommunityFailure.cameraDenied:
      return l10n.cameraDenied;
    case CommunityFailure.galleryDenied:
      return l10n.galleryDenied;
    case CommunityFailure.noCamera:
      return l10n.noCamera;
    case CommunityFailure.invalidText:
    case CommunityFailure.unknown:
      return l10n.somethingWrong;
  }
}

/// What is wrong with a question or an answer, in the language of the app.
String textProblemMessage(AppLocalizations l10n, TextProblem problem) {
  switch (problem) {
    case TextProblem.empty:
      return l10n.textEmpty;
    case TextProblem.tooLong:
      return l10n.textTooLong('$communityTextMaxLength');
    case TextProblem.badCharacters:
      return l10n.textBadCharacters;
  }
}

/// The name of a region ("sfax" -> "صفاقس" / "Sfax"); null = unknown.
String? regionName(AppLocalizations l10n, String? code) => switch (code) {
  'sfax' => l10n.regionSfax,
  'kairouan' => l10n.regionKairouan,
  'sidi_bouzid' => l10n.regionSidiBouzid,
  'gafsa' => l10n.regionGafsa,
  'kasserine' => l10n.regionKasserine,
  'mahdia' => l10n.regionMahdia,
  'zaghouan' => l10n.regionZaghouan,
  _ => null,
};

/// "الآن", "منذ 5 دقائق", "منذ ساعتين", "منذ 3 أيام"...
String timeAgo(AppLocalizations l10n, DateTime date, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(date);
  if (age.inMinutes < 1) return l10n.timeJustNow;
  if (age.inHours < 1) return l10n.timeMinutesAgo(age.inMinutes);
  if (age.inDays < 1) return l10n.timeHoursAgo(age.inHours);
  return l10n.timeDaysAgo(age.inDays);
}

/// The author's name, or "فلاح" when he has none.
String authorName(AppLocalizations l10n, Author author) =>
    author.fullName ?? l10n.farmerFallbackName;

/// "القيروان · منذ ساعتين" (the region only when it is known).
String placeAndTime(AppLocalizations l10n, Author author, DateTime date) {
  final region = regionName(l10n, author.region);
  final time = timeAgo(l10n, date);
  return region == null ? time : '$region · $time';
}
