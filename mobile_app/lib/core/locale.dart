// The language of the app: Arabic (the default, right to left) or French.
// The texts are in lib/l10n/app_ar.arb and app_fr.arb.
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// The language chosen by the user. The whole app listens to it
/// (see app.dart), so changing it switches every screen at once.
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('ar'));

/// Where the language is remembered on the phone.
const _savedLanguageKey = 'language';

/// Switches the app to 'ar' or 'fr', and remembers it on the phone (the
/// next start opens in this language, even before the login).
void setLanguage(String languageCode) {
  appLocale.value = Locale(languageCode);
  SharedPreferences.getInstance()
      .then((saved) => saved.setString(_savedLanguageKey, languageCode))
      .ignore(); // not saved (no storage): the app just opens in Arabic
}

/// At the start of the app: the language remembered on this phone.
Future<void> loadSavedLanguage() async {
  try {
    final saved = await SharedPreferences.getInstance();
    final code = saved.getString(_savedLanguageKey);
    if (code == 'ar' || code == 'fr') appLocale.value = Locale(code!);
  } catch (_) {
    // Nothing remembered: Arabic.
  }
}

extension AppTexts on BuildContext {
  /// The texts in the current language, e.g. `context.l10n.homeTitle`.
  /// (l10n = "localization": l + 10 letters + n.)
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// true when the app is in French.
  bool get isFrench => Localizations.localeOf(this).languageCode == 'fr';
}
