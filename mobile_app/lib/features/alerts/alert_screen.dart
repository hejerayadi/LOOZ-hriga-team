// One alert: tree A-18 needs water ("تحتاج ماء"). The farmer taps "تمّ"
// when it's done, and the screen becomes happy ("أحسنت!").
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../data/fake_data.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/mood_face.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/speaker_button.dart';
import '../../shared/widgets/symbol_text.dart';

class AlertScreen extends StatelessWidget {
  const AlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Like in the design, "done" stays done (here: while the app runs).
    return ValueListenableBuilder<bool>(
      valueListenable: fakeTreeWatered,
      builder: (context, done, _) => ShellPage(
        children: [
          ScreenTitle(
            title: done ? l10n.wellDone : l10n.needsWater,
            subtitle: l10n.treeName,
          ),
          _TreeHealth(done: done),
          const SizedBox(height: 14),
          CssBox(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            shadows: AppShadows.card,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.whatToDo, style: AppTextStyles.cardTitle),
                      Text(
                        done
                            ? l10n.treeHappy
                            : l10n.waterLiters('$fakeWaterLiters'),
                        style: AppTextStyles.of(18),
                      ),
                    ],
                  ),
                ),
                const SpeakerButton(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!done)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14)
                  .add(const EdgeInsets.only(top: 14, bottom: 14)),
              child: Row(
                children: [
                  const LoozIcon(AppIcon.sun),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      l10n.noRainDays('$fakeDaysWithoutRain'),
                      style: AppTextStyles.of(17),
                    ),
                  ),
                ],
              ),
            ),
          ActionButton(
            label: l10n.done,
            onPressed: () => fakeTreeWatered.value = true,
          ),
        ],
      ),
    );
  }
}

/// The big card with the face and the tree (sad, then happy with petals).
class _TreeHealth extends StatelessWidget {
  const _TreeHealth({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return CssBox(
      height: 300,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      gradient: CssLinearGradient(
        angle: 180,
        colors: done
            ? const [AppColors.sky, AppColors.mint]
            : const [AppColors.peach, AppColors.yellow],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Behind the face, like in the design.
          if (done) const Positioned(top: 20, child: _FallingPetals()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MoodFace(level: done ? StatusLevel.good : StatusLevel.danger),
                const SizedBox(height: 16),
                LoozIcon(
                  AppIcon.tree,
                  size: 100,
                  color: done ? const Color(0xFF3D7D42) : AppColors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "✿ · ✿ · ✿" going down and up, a little turned (2 s, again and again).
class _FallingPetals extends StatefulWidget {
  const _FallingPetals();

  @override
  State<_FallingPetals> createState() => _FallingPetalsState();
}

class _FallingPetalsState extends State<_FallingPetals>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fall = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No movement when the phone asks for it ("remove animations").
    if (MediaQuery.disableAnimationsOf(context)) {
      _fall.stop();
    } else if (!_fall.isAnimating) {
      _fall.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final petals = SymbolText(
      '✿ · ✿ · ✿',
      style: AppTextStyles.of(28).copyWith(color: const Color(0xFF5F9F51)),
    );
    if (still) return petals;
    return AnimatedBuilder(
      animation: _fall,
      builder: (context, child) {
        final t = Curves.ease.transform(_fall.value);
        return Transform.translate(
          offset: Offset(0, 25 * t),
          child: Transform.rotate(angle: 8 * t * 3.14159 / 180, child: child),
        );
      },
      child: petals,
    );
  }
}
