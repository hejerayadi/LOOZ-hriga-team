// After the payment: "جاري بناء بستانك…" while the database builds the
// orchard from the draft (orchard_apply_design: the zones, one sensor per
// zone, the trees in rows, one installation visit). Then:
//   - at the sign-up: the welcome, whose "ابدأ" opens "بستاني ★";
//   - in the app: "بستاني ★" with the orchard in 3D.
// It failed (no internet...): "حاول مرة أخرى" (the payment is kept).
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';
import '../../data/orchard_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/looz_background.dart';
import '../onboarding/auth_messages.dart';
import '../onboarding/welcome_screen.dart';

class BuildOrchardScreen extends StatefulWidget {
  const BuildOrchardScreen({super.key, this.signUp = false});

  final bool signUp;

  @override
  State<BuildOrchardScreen> createState() => _BuildOrchardScreenState();
}

class _BuildOrchardScreenState extends State<BuildOrchardScreen> {
  AuthFailure? _failure;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    setState(() => _failure = null);
    try {
      await orchardService.buildOrchard();
    } on AuthError catch (error) {
      if (mounted) setState(() => _failure = error.failure);
      return;
    }
    if (!mounted) return;
    if (widget.signUp) {
      replaceAllWith(context, const WelcomeScreen(openTab: AppTab.orchard));
    } else {
      currentTab.value = AppTab.orchard;
      replaceAllWith(context, const MainShell());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = _failure;
    return Scaffold(
      body: LoozBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconBlob(icon: AppIcon.tree, size: 100, iconSize: 54),
                const SizedBox(height: 22),
                if (failure == null) ...[
                  Text(
                    l10n.buildingOrchard,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.of(24, FontWeight.w800),
                  ),
                  const SizedBox(height: 22),
                  const CircularProgressIndicator(),
                ] else ...[
                  AuthNote.failure(failure),
                  const SizedBox(height: 18),
                  ActionButton(label: l10n.tryAgain, onPressed: _build),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
