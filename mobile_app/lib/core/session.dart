// The logged-in user while the app runs.
// Supabase keeps the session on the phone, so the user stays logged in
// after closing the app, until "تسجيل الخروج" in the Profile tab.
import 'package:flutter/foundation.dart';

import '../data/auth_service.dart';
import '../data/user_profile.dart';
import 'locale.dart';
import 'plans.dart';
import 'supabase_config.dart';

AuthService? _authService;

/// The login system: Supabase in the app (the tests put a fake one).
AuthService get authService => _authService ??= SupabaseAuthService(supabase);
set authService(AuthService service) => _authService = service;

/// The logged-in farmer (null = nobody). Screens listen to it, e.g. to
/// show the first name on Home.
final ValueNotifier<UserProfile?> currentUser = ValueNotifier(null);

/// After the code: reads the profile and the plan. The language chosen on
/// the first screen is saved (it may differ from the last time).
Future<UserProfile> startSessionAfterLogin() async {
  var profile = await authService.loadProfile();
  final language = appLocale.value.languageCode;
  if (profile.language != language) {
    profile = await authService.saveLanguage(language);
  }
  await _use(profile);
  return profile;
}

/// When the app opens with a saved session: the profile, its language and
/// the plan.
Future<UserProfile> resumeSession() async {
  final profile = await authService.loadProfile();
  setLanguage(profile.language);
  await _use(profile);
  return profile;
}

/// Keeps a profile just saved (name, pack) as the current one.
void updateUser(UserProfile profile) => currentUser.value = profile;

Future<void> _use(UserProfile profile) async {
  currentPlan.value = await authService.loadPlan();
  currentUser.value = profile;
}

/// The "عربي | FR" switch: changes the language at once and, when someone
/// is logged in, saves it in the profile. (Without internet it is not
/// saved: the app opens in the saved language next time.)
void changeLanguage(String languageCode) {
  setLanguage(languageCode);
  final user = currentUser.value;
  if (user == null || user.language == languageCode) return;
  currentUser.value = user.copyWith(language: languageCode);
  authService.saveLanguage(languageCode).then<void>(
    (saved) {
      if (currentUser.value?.id == saved.id) currentUser.value = saved;
    },
    onError: (Object _) {},
  );
}

/// Logs out: forgets the session on this phone.
Future<void> logOut() async {
  await authService.signOut();
  currentUser.value = null;
  currentPlan.value = Plan.free;
}
