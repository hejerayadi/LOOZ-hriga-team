// Login, step 3: "مرحبًا يا محمد" with a smiling face, then the app.
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/enums.dart';
import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/mood_face.dart';

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
                    l10n.welcomeUser(l10n.demoFirstName),
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
