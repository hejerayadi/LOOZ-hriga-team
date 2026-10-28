// "أنا أسمعك": the assistant listens (the orb breathes, the bars move),
// then thinks ("جاري النظر…") and shows its answer.
//
// DEMO: the microphone is not used yet. After a few seconds (or a tap on
// the orb) the app "has heard" the question.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/assistant_orb.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/speaker_button.dart';
import '../../shared/widgets/symbol_text.dart';
import '../camera/thinking_screen.dart';

/// How long the demo "listens".
const listeningTime = Duration(seconds: 4);

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  // Like the design: every 1.4 s the orb fades to half and comes back.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(listeningTime, _heard);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No movement when the phone asks for it ("remove animations").
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  void _heard() {
    if (!mounted) return;
    _timer.cancel();
    replaceWith(context, const ThinkingScreen());
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final still = MediaQuery.disableAnimationsOf(context);
    return ShellPage(
      children: [
        const SizedBox(height: 120),
        CssBox(
          color: const Color(0xCCFFFFFF),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          shadows: AppShadows.card,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: _heard,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final t = still
                          ? 0.0
                          : Curves.ease.transform(_pulse.value);
                      return Opacity(opacity: 1 - 0.5 * t, child: child);
                    },
                    child: const AssistantOrb(
                      size: OrbSize.giant,
                      icon: AppIcon.mic,
                      iconSize: 44,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.listening,
                textAlign: TextAlign.center,
                style: AppTextStyles.headline,
              ),
              const SizedBox(height: 30),
              _SoundWave(still: still),
              const SizedBox(height: 30),
              Container(
                height: 68,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.mintWhite,
                  borderRadius: BorderRadius.circular(AppRadius.keypad),
                ),
                child: Row(
                  children: [
                    const SpeakerButton(),
                    const SizedBox(width: 15),
                    Flexible(
                      child: Text(
                        l10n.speakFreely,
                        style: AppTextStyles.of(18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The bars "▂ ▅ ▃ ▇ ▅ ▂ ▆" of the design, moving up and down.
class _SoundWave extends StatefulWidget {
  const _SoundWave({required this.still});

  /// true = no movement (the phone's "remove animations" setting).
  final bool still;

  @override
  State<_SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<_SoundWave> {
  // From low to high, and the design's bars as heights in this list.
  static const _levels = ['▂', '▃', '▅', '▆', '▇'];
  static const _design = [0, 2, 1, 4, 2, 0, 3];

  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.still) {
      _timer = Timer.periodic(const Duration(milliseconds: 180), (_) {
        setState(() => _step++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Each bar takes the height of its neighbour: the wave moves along.
    final bars = [
      for (var i = 0; i < _design.length; i++)
        _levels[_design[(i + _step) % _design.length]],
    ];
    return SymbolText(
      bars.join(' '),
      textAlign: TextAlign.center,
      style: AppTextStyles.of(30)
          .copyWith(color: const Color(0xFF57934A), letterSpacing: 5),
    );
  }
}
