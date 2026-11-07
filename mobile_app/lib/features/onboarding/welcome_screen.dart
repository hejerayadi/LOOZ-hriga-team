// End of the sign-up: "مرحبًا يا <first name>" with a smiling face, then
// the app. A new expert reads that his badge comes once he is checked.
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/enums.dart';
import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/mood_face.dart';
import '../../shared/widgets/symbol_text.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _start(BuildContext context) {
    currentTab.value = AppTab.home;
    replaceAllWith(context, const MainShell());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final system = MediaQuery.paddingOf(context);
    return Scaffold(
      body: LoozBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageSide(context, shrink: false),
            system.top + 28,
            AppSpacing.pageSide(context, shrink: false),
            system.bottom + 30,
          ),
          children: [
            const LoozHeader(),
            // Like in the design: a tall area, with its content in the middle.
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 800),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MoodFace(level: StatusLevel.good),
                  const SizedBox(height: 18),
                  Text(
                    l10n.welcomeUser(currentUser.value?.firstName ?? ''),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headline,
                  ),
                  const SizedBox(height: 18 + 6),
                  Opacity(
                    opacity: 0.7,
                    child: Text(
                      l10n.orchardReady,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle,
                    ),
                  ),
                  if (currentUser.value case final user?
                      when user.isExpert && !user.verified) ...[
                    const SizedBox(height: 18),
                    SymbolText(
                      l10n.expertPendingNote,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.of(17, FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 18 + 24),
                  ActionButton(
                    label: l10n.start,
                    onPressed: () => _start(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
