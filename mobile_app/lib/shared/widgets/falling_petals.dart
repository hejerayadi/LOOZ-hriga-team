// "✿ · ✿ · ✿" going down and up, a little turned (2 s, again and again):
// the design's "done" animation ("أحسنت!"). Still when the phone asks for
// no animations.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'symbol_text.dart';

class FallingPetals extends StatefulWidget {
  const FallingPetals({super.key});

  @override
  State<FallingPetals> createState() => _FallingPetalsState();
}

class _FallingPetalsState extends State<FallingPetals>
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
