// Where the user goes after the login, and the first screen of the app.
//
// Sign up: start → phone → code → who are you (farmer or expert) → your
// information (only the boxes of that person), then
//   farmer: the pack: Free → welcome → Home
//                     Premium → "ارسم بستانك" (the designer: draw, then the
//                     price and the DEMO payment) → welcome
//   expert: welcome → Home (the Free features: no pack, no payment)
// Sign in: start → phone → code → Home.
// Stopped in the middle (e.g. closed the app on the pack screen): the next
// login continues at the missing step.
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';
import '../../data/user_profile.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/looz_logo.dart';
import '../orchard_designer/designer_start_screen.dart';
import 'auth_messages.dart';
import 'pack_screen.dart';
import 'role_screen.dart';
import 'sign_up_info_screen.dart';
import 'start_screen.dart';

/// Opens the next step for this user (the login screens are forgotten,
/// so "back" does not go back to them).
void openNextStep(BuildContext context, UserProfile profile) {
  if (!profile.hasChosenPlan) {
    if (!profile.hasSignUpInfo) {
      replaceAllWith(context, const RoleScreen());
    } else if (profile.isExpert) {
      // An expert never sees the packs: his information, then welcome.
      replaceAllWith(context, const SignUpInfoScreen(role: UserRole.expert));
    } else {
      replaceAllWith(context, const PackScreen());
    }
  } else if (profile.waitsForPayment && profile.chosenPlan == Plan.paid) {
    // Premium chosen, not paid yet: the designer (it ends with the payment).
    replaceAllWith(context, const DesignerStartScreen(signUp: true));
  } else {
    currentTab.value = AppTab.home;
    replaceAllWith(context, const MainShell());
  }
}

/// The first screen of the app. Logged in (the session is kept on the
/// phone): reads the profile, then goes on. Not logged in: the start screen.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
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
        if (mounted) replaceAllWith(context, const StartScreen());
      } else if (mounted) {
        setState(() => _failure = failure);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) return const StartScreen();
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
                  ActionButton(
                    label: context.l10n.tryAgain,
                    onPressed: _resume,
                  ),
                ],
              ),
      ),
    );
  }
}
