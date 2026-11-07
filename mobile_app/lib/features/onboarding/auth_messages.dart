// The messages of the login and sign-up screens (errors and infos), in
// the style of the design's state cards ("لا يوجد إنترنت", "حاول مرة أخرى").
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validators.dart';
import '../../data/auth_service.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';

/// The text of an error, in the language of the app.
String failureMessage(AppLocalizations l10n, AuthFailure failure) {
  switch (failure) {
    case AuthFailure.noInternet:
      return l10n.errorNoInternet;
    case AuthFailure.noAccount:
      return l10n.errorNoAccount;
    case AuthFailure.wrongCode:
      return l10n.errorWrongCode;
    case AuthFailure.tooManyTries:
      return l10n.errorTooManyTries;
    case AuthFailure.cannotReceiveCode:
      return l10n.errorCannotReceiveCode;
    case AuthFailure.invalidPhone:
      return l10n.errorInvalidPhone;
    case AuthFailure.phoneTaken:
      return l10n.errorPhoneTaken;
    case AuthFailure.invalidName:
      return l10n.errorInvalidName;
    case AuthFailure.sessionExpired:
      return l10n.errorSessionExpired;
    case AuthFailure.unknown:
      return l10n.somethingWrong;
  }
}

/// What is wrong with a name, in the language of the app.
String nameProblemMessage(AppLocalizations l10n, NameProblem problem) {
  switch (problem) {
    case NameProblem.empty:
      return l10n.nameRequired;
    case NameProblem.tooLong:
      return l10n.nameTooLong('$nameMaxLength');
    case NameProblem.badCharacters:
      return l10n.nameBadCharacters;
  }
}

/// A message card: an icon on a blob and a bold text.
class AuthNote extends StatelessWidget {
  /// An error (e.g. "wrong code").
  const AuthNote.failure(AuthFailure this.failure, {super.key})
    : info = null,
      error = true;

  /// A good news (e.g. "a new code was sent").
  const AuthNote.info(String this.info, {super.key})
    : failure = null,
      error = false;

  /// Another error, already written (e.g. a payment message).
  const AuthNote.error(String this.info, {super.key})
    : failure = null,
      error = true;

  final AuthFailure? failure;
  final String? info;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    // Like the state cards: no internet = wifi on sky, wait = clock on
    // yellow, other errors = warning on peach; good news = check on mint.
    final (icon, color) = switch (failure) {
      null when error => (AppIcon.warning, AppColors.peach),
      null => (AppIcon.check, AppColors.mint),
      AuthFailure.noInternet => (AppIcon.wifi, AppColors.sky),
      AuthFailure.tooManyTries => (AppIcon.clock, AppColors.yellow),
      AuthFailure.noAccount => (AppIcon.user, AppColors.peach),
      _ => (AppIcon.warning, AppColors.peach),
    };
    final text = failure == null
        ? info!
        : failureMessage(context.l10n, failure);
    return Semantics(
      liveRegion: true,
      child: CssBox(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        shadows: AppShadows.card,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconBlob(icon: icon, size: 46, iconSize: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: AppTextStyles.of(16, FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
