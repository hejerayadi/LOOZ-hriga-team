// "جاري النظر…": the assistant looks at the photo (or the question),
// then shows the result.
//
// DEMO: no AI yet. After a short time the (fake) result is shown.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/fake_data.dart';
import '../../shared/widgets/assistant_orb.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_logo.dart';
import '../../shared/widgets/symbol_text.dart';
import 'result_screen.dart';

/// "● ● ● ○": how sure the AI is (3 dots out of 4).
String confidenceDots() =>
    List.generate(4, (i) => i < fakeConfidence ? '●' : '○').join(' ');

class ThinkingScreen extends StatefulWidget {
  const ThinkingScreen({super.key});

  @override
  State<ThinkingScreen> createState() => _ThinkingScreenState();
}

class _ThinkingScreenState extends State<ThinkingScreen> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(fakeThinkingTime, () {
      if (mounted) replaceWith(context, const ResultScreen());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.paddingOf(context);
    return Scaffold(
      body: LoozBackground(
        child: Stack(
          children: [
            Positioned(
              top: system.top + 30,
              left: 0,
              right: 0,
              child: const Center(child: LoozLogo()),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 28),
                    const AssistantOrb(size: OrbSize.giant),
                    const SizedBox(height: 28),
                    Text(
                      context.l10n.looking,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headline,
                    ),
                    const SizedBox(height: 20),
                    SymbolText(
                      confidenceDots(),
                      style: AppTextStyles.of(20)
                          .copyWith(color: AppColors.leaf, letterSpacing: 8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
