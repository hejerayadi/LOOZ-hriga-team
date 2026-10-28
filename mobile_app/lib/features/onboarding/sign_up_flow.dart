// Where the user goes after the login, and the first screen of the app.
//
// New user:      language → phone → code → name → pack → (paid pack: pay now
//                or later) → welcome → Home.
// Existing user: phone → code → Home.
// Stopped in the middle (e.g. closed the app on the pack screen): the next
// login continues at the missing step.
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';
import '../../data/user_profile.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/looz_logo.dart';
import 'auth_messages.dart';
import 'language_screen.dart';
import 'name_screen.dart';
import 'pack_screen.dart';

/// Opens the next step for this user (the login screens are forgotten,
/// so "back" does not go back to them).
void openNextStep(BuildContext context, UserProfile profile) {
  if (!profile.hasName) {
    replaceAllWith(context, const NameScreen());
  } else if (!profile.hasChosenPlan) {
    replaceAllWith(context, const PackScreen());
  } else {
    currentTab.value = AppTab.home;
    replaceAllWith(context, const MainShell());
  }
}

/// The first screen of the app. Logged in (the session is kept on the
/// phone): reads the profile, then goes on. Not logged in: the language.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late final bool _loggedIn = authService.hasSession;
  AuthFailure? _failure;

  @override
  void initState() {
    super.initState();
    if (_loggedIn) _resume();
  }

  Future<void> _resume() async {
    setState(() => _failure = null);
    try {
      final profile = await resumeSession();
      if (mounted) openNextStep(context, profile);
    } catch (error) {
      final failure = failureOf(error);
      if (failure == AuthFailure.sessionExpired) {
        // The session is not valid any more: log in again.
        await logOut();
        if (mounted) replaceAllWith(context, const LanguageScreen());
      } else if (mounted) {
        setState(() => _failure = failure);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) return const LanguageScreen();
    final failure = _failure;
    final system = MediaQuery.paddingOf(context);
    return Scaffold(
      body: LoozBackground(
        child: failure == null
            // Reading the profile: the logo, in the middle.
            ? const Center(child: LoozLogo())
            // No internet (or another error): the message and "حاول مرة أخرى".
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageSide(context, shrink: false),
                  system.top + 28,
                  AppSpacing.pageSide(context, shrink: false),
                  system.bottom + 30,
                ),
                children: [
                  const LoozHeader(),
                  const SizedBox(height: 64),
                  AuthNote.failure(failure),
                  const SizedBox(height: 24),
                  ActionButton(label: context.l10n.tryAgain, onPressed: _resume),
                ],
              ),
      ),
    );
  }
}
