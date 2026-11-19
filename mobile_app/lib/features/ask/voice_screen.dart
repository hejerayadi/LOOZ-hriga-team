// The voice assistant "لوز" (Bêta, paid pack): the farmer taps the big
// microphone and talks; "لوز" answers with its voice (Gemini Live) and both
// texts appear on the screen. The conversation itself is in
// voice_session.dart.
//
// The first time: "قبل أن تتكلّم" (the voice goes to Google; LOOZ records
// nothing). The microphone is paused while "لوز" speaks; a tap on the orb
// stops its voice. Free farmers never reach this screen (openFeature), and
// a pack that ended here shows the locked screen.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/voice_service.dart';
import '../../data/voice_tools.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/assistant_orb.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/symbol_text.dart';
import '../camera/diagnosis_widgets.dart';
import 'voice_session.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Like the design: the orb fades to half and comes back while it listens
  // or speaks.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final VoiceSession _session = VoiceSession(
    language: () => appLocale.value.languageCode,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(_changed);
    _session.load();
  }

  void _changed() {
    if (!mounted) return;
    if (_session.failure == VoiceFailure.notPaid) {
      // The paid pack ended: the locked screen ("★ ابدأ").
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) goToTab(context, AppTab.orchard);
      });
    }
    setState(() {});
    _animate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate();
  }

  /// The orb breathes while "لوز" listens or speaks (never when the phone
  /// asks for no movement).
  void _animate() {
    final moving =
        const {
          VoiceStage.listening,
          VoiceStage.speaking,
        }.contains(_session.stage) &&
        !MediaQuery.disableAnimationsOf(context);
    if (moving && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!moving && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The app hidden (home button, another app): the microphone stops.
    // ("inactive" is not enough: the question "allow the microphone?"
    // makes the app inactive for a moment.)
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_session.talking) _session.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_changed);
    _session.dispose(); // ends a running conversation
    _pulse.dispose();
    super.dispose();
  }

  /// "حاول مرة أخرى": the check again, or a new conversation.
  void _retry() {
    if (_session.quota == null) {
      _session.load();
    } else {
      _session.start();
    }
  }

  void _tapOrb() {
    switch (_session.stage) {
      case VoiceStage.ready || VoiceStage.ended:
        if (_canTalkAgain) _session.start();
      case VoiceStage.speaking:
        _session.interrupt();
      case VoiceStage.failed when _retryable:
        _retry();
      default:
        break;
    }
  }

  bool get _canTalkAgain =>
      (_session.leftToday ?? VoiceQuota.minSeconds) >= VoiceQuota.minSeconds;

  bool get _retryable => const {
    VoiceFailure.noInternet,
    VoiceFailure.unavailable,
    VoiceFailure.micDenied,
    VoiceFailure.unknown,
  }.contains(_session.failure);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = _session;
    final consent = session.stage == VoiceStage.consent;
    return ShellPage(
      children: [
        const SizedBox(height: 56),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.voiceName, style: AppTextStyles.sectionTitle),
            const SizedBox(width: 10),
            const BetaTag(),
          ],
        ),
        const SizedBox(height: 14),
        if (consent)
          _ConsentCard(
            freeTier: session.quota?.googleFreeTier ?? true,
            onAccept: session.accept,
            onRefuse: () => Navigator.of(context).maybePop(),
          )
        else ...[
          _orbCard(context),
          // The button right under the card (always visible), then the
          // texts of the conversation.
          const SizedBox(height: 16),
          ..._buttons(context),
          if (session.lines.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Conversation(lines: session.lines),
          ],
        ],
        const SizedBox(height: 16),
        Text(
          l10n.voiceAdvice,
          textAlign: TextAlign.center,
          style: AppTextStyles.of(14, FontWeight.w600),
        ),
      ],
    );
  }

  Widget _orbCard(BuildContext context) {
    final l10n = context.l10n;
    final session = _session;
    final stage = session.stage;
    final still = MediaQuery.disableAnimationsOf(context);
    final failure = session.failure;
    final status = switch (stage) {
      VoiceStage.checking || VoiceStage.connecting => l10n.voiceConnecting,
      VoiceStage.ready || VoiceStage.consent => l10n.speakHint,
      VoiceStage.listening => l10n.voiceListening,
      VoiceStage.thinking => l10n.voiceThinking,
      VoiceStage.speaking => l10n.voiceSpeaking,
      VoiceStage.ended => l10n.voiceEnded,
      VoiceStage.failed => null,
    };
    final moving =
        stage == VoiceStage.listening || stage == VoiceStage.speaking;
    // Once the texts appear, a smaller orb and no wave (the orb still
    // breathes): the button and the texts stay above the bars.
    final compact = session.lines.isNotEmpty;
    return CssBox(
      color: const Color(0xCCFFFFFF),
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      shadows: AppShadows.card,
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: compact ? 18 : 26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Semantics(
              button: true,
              label: status ?? l10n.tryAgain,
              child: GestureDetector(
                onTap: _tapOrb,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final t = still ? 0.0 : Curves.ease.transform(_pulse.value);
                    return Opacity(opacity: 1 - 0.5 * t, child: child);
                  },
                  child: AssistantOrb(
                    size: compact ? OrbSize.normal : OrbSize.giant,
                    icon: AppIcon.mic,
                    iconSize: compact ? 30 : 44,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 22),
          if (status != null)
            Semantics(
              liveRegion: true,
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: AppTextStyles.headline,
              ),
            ),
          if (failure != null && stage == VoiceStage.failed)
            CameraNote(text: voiceFailureMessage(l10n, failure)),
          if (stage == VoiceStage.thinking &&
              session.lookingAt == orchardTool) ...[
            const SizedBox(height: 10),
            Text(
              l10n.voiceLookingOrchard,
              textAlign: TextAlign.center,
              style: AppTextStyles.of(17, FontWeight.w700),
            ),
          ],
          if (stage == VoiceStage.speaking) ...[
            const SizedBox(height: 8),
            Text(
              l10n.voiceTapToInterrupt,
              textAlign: TextAlign.center,
              style: AppTextStyles.of(15, FontWeight.w600),
            ),
          ],
          if (moving && !compact) ...[
            const SizedBox(height: 18),
            _SoundWave(still: still),
          ],
          SizedBox(height: compact ? 8 : 14),
          _timeLine(context),
        ],
      ),
    );
  }

  /// "2:41" during a conversation; the minutes left today otherwise.
  Widget _timeLine(BuildContext context) {
    final session = _session;
    final style = AppTextStyles.of(16, FontWeight.w700);
    if (session.talking && session.stage != VoiceStage.connecting) {
      final s = session.secondsLeft;
      return Text(
        '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: style,
      );
    }
    final left = session.leftToday;
    if (left == null ||
        session.stage == VoiceStage.failed ||
        session.stage == VoiceStage.checking) {
      return const SizedBox.shrink();
    }
    return Text(
      context.l10n.voiceMinutesLeft((left / 60).ceil()),
      textAlign: TextAlign.center,
      style: style,
    );
  }

  List<Widget> _buttons(BuildContext context) {
    final l10n = context.l10n;
    final session = _session;
    return switch (session.stage) {
      VoiceStage.ready => [
        ActionButton(label: l10n.speak, onPressed: session.start),
      ],
      VoiceStage.connecting ||
      VoiceStage.listening ||
      VoiceStage.thinking ||
      VoiceStage.speaking => [
        ActionButton(label: l10n.voiceStop, onPressed: session.stop),
      ],
      VoiceStage.ended when _canTalkAgain => [
        ActionButton(label: l10n.voiceTalkAgain, onPressed: session.start),
      ],
      VoiceStage.ended => [CameraNote(text: l10n.voiceLimitReached)],
      VoiceStage.failed when _retryable => [
        ActionButton(label: l10n.tryAgain, onPressed: _retry),
      ],
      _ => const [],
    };
  }
}

/// The message of a failure.
String voiceFailureMessage(AppLocalizations l10n, VoiceFailure failure) =>
    switch (failure) {
      VoiceFailure.noInternet => l10n.needInternet,
      VoiceFailure.limitDay => l10n.voiceLimitReached,
      VoiceFailure.busy => l10n.voiceBusy,
      VoiceFailure.off => l10n.voiceOff,
      VoiceFailure.micDenied => l10n.voiceMicNeeded,
      VoiceFailure.sessionExpired => l10n.errorSessionExpired,
      VoiceFailure.unavailable ||
      VoiceFailure.notPaid ||
      VoiceFailure.consent ||
      VoiceFailure.unknown => l10n.voiceUnavailable,
    };

/// "قبل أن تتكلّم": the first time only.
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.freeTier,
    required this.onAccept,
    required this.onRefuse,
  });

  /// The Gemini key is on Google's free tier: one more sentence.
  final bool freeTier;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CssBox(
      color: const Color(0xEEFFFFFF),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      shadows: AppShadows.card,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AssistantOrb(icon: AppIcon.mic, iconSize: 30)),
          const SizedBox(height: 16),
          Text(
            l10n.voiceConsentTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 12),
          Text(
            freeTier
                ? '${l10n.voiceConsentBody} ${l10n.voiceConsentFreeTier}'
                : l10n.voiceConsentBody,
            style: AppTextStyles.of(18, FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ActionButton(label: l10n.voiceConsentAccept, onPressed: onAccept),
          const SizedBox(height: 10),
          ActionButton(
            label: l10n.voiceConsentRefuse,
            secondary: true,
            onPressed: onRefuse,
          ),
        ],
      ),
    );
  }
}

/// The texts of the conversation: "أنت" and "لوز" (the last ones).
class _Conversation extends StatelessWidget {
  const _Conversation({required this.lines});

  final List<VoiceLine> lines;

  /// Only the last question and answer (the voice is what counts; they
  /// stay above the bars).
  static const shown = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final last = lines.length > shown
        ? lines.sublist(lines.length - shown)
        : lines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in last)
          if (line.text.trim().isNotEmpty)
            Align(
              alignment: line.fromFarmer
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.centerEnd,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: line.fromFarmer
                      ? const Color(0xEEFFFFFF)
                      : AppColors.softGreen,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.fromFarmer ? l10n.voiceYou : l10n.voiceName,
                      style: AppTextStyles.of(14, FontWeight.w800),
                    ),
                    Text(
                      line.text.trim(),
                      style: AppTextStyles.of(17, FontWeight.w600),
                    ),
                  ],
                ),
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
