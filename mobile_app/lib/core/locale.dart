// The language of the app: Arabic (the default, right to left) or French.
// The texts are in lib/l10n/app_ar.arb and app_fr.arb.
import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// The language chosen by the user. The whole app listens to it
/// (see app.dart), so changing it switches every screen at once.
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('ar'));

/// Switches the app to 'ar' or 'fr'.
void setLanguage(String languageCode) => appLocale.value = Locale(languageCode);

extension AppTexts on BuildContext {
  /// The texts in the current language, e.g. `context.l10n.homeTitle`.
  /// (l10n = "localization": l + 10 letters + n.)
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// true when the app is in French.
  bool get isFrench => Localizations.localeOf(this).languageCode == 'fr';
}
