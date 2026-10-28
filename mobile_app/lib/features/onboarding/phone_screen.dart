// Login, step 1 and 2: the phone number, then the code sent by SMS
// (Supabase Auth, see lib/data/auth_service.dart).
// After the code: a new user gives his name and chooses a pack; a user who
// already finished the sign-up goes straight to Home (see sign_up_flow.dart).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validators.dart';
import '../../data/auth_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/symbol_text.dart';
import '../../shared/widgets/text_link.dart';
import 'auth_messages.dart';
import 'sign_up_flow.dart';

/// Step 1: the phone number (8 digits after +216).
class PhoneScreen extends StatelessWidget {
  const PhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _KeypadScreen(
      title: l10n.phoneTitle,
      subtitle: l10n.phoneSubtitle,
      action: l10n.sendCode,
      busyAction: l10n.sending,
      length: phoneDigits,
      // "+216 12 345 •••": the digits typed, then dots for the missing ones.
      display: (digits) {
        final slots = digits.padRight(phoneDigits, '•');
        final groups = <String>[];
        var start = 0;
        for (final size in phoneGroups) {
          groups.add(slots.substring(start, start + size));
          start += size;
        }
        return '$phonePrefix ${groups.join(' ')}';
      },
      onDone: (digits) async {
        final phone = phoneFromDigits(digits);
        await authService.sendCode(
          phone,
          language: appLocale.value.languageCode,
        );
        if (context.mounted) openScreen(context, CodeScreen(phone: phone));
      },
    );
  }
}

/// Step 2: the code of 6 digits sent to [phone].
class CodeScreen extends StatelessWidget {
  const CodeScreen({super.key, required this.phone});

  /// "+21698123456".
  final String phone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _KeypadScreen(
      title: l10n.codeTitle,
      subtitle: l10n.codeSubtitle,
      action: l10n.confirm,
      busyAction: l10n.checking,
      length: codeLength,
      // "1 2 • • • •"
      display: (digits) =>
          digits.padRight(codeLength, '•').split('').join(' '),
      onDone: (code) async {
        await authService.verifyCode(phone, code);
        final profile = await startSessionAfterLogin();
        if (context.mounted) openNextStep(context, profile);
      },
      onResend: () => authService.sendCode(
        phone,
        language: appLocale.value.languageCode,
      ),
    );
  }
}

/// The layout of both steps: title, the number, a keypad and the button.
class _KeypadScreen extends StatefulWidget {
  const _KeypadScreen({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.busyAction,
    required this.length,
    required this.display,
    required this.onDone,
    this.onResend,
  });

  final String title;
  final String subtitle;

  /// Text of the big button, and while waiting for the server.
  final String action;
  final String busyAction;

  /// How many digits are needed.
  final int length;

  /// The text shown above the keypad, from the digits typed.
  final String Function(String digits) display;

  /// Called with the digits when the button is tapped. Throws an
  /// AuthError when it fails (the message is shown).
  final Future<void> Function(String digits) onDone;

  /// "أعد إرسال الرمز" (code screen only).
  final Future<void> Function()? onResend;

  @override
  State<_KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<_KeypadScreen> {
  String _digits = '';
  bool _busy = false;
  AuthFailure? _failure;
  bool _resent = false;

  void _onKey(String key) {
    if (_busy) return;
    setState(() {
      _failure = null;
      _resent = false;
      if (key == '⌫') {
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
      } else if (key != '+' && _digits.length < widget.length) {
        // "+" does nothing: the country code (+216) is already there.
        _digits += key;
      }
    });
  }

  /// Waits for the server; shows the message if it fails.
  Future<void> _call(Future<void> Function() call, {bool resend = false}) async {
    setState(() {
      _busy = true;
      _failure = null;
      _resent = false;
    });
    try {
      await call();
      if (mounted && resend) setState(() => _resent = true);
    } catch (error) {
      if (mounted) setState(() => _failure = failureOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final system = MediaQuery.paddingOf(context);
    final complete = _digits.length == widget.length;
    final failure = _failure;
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
            ScreenTitle(
              title: widget.title,
              subtitle: widget.subtitle,
              top: 64,
            ),
            // Numbers are always written left to right.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  const SizedBox(height: 10), // 28 in all, with the title's 18
                  Container(
                    height: 74,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: AppShadows.card,
                    ),
                    child: Text(
                      widget.display(_digits),
                      style: AppTextStyles.keypad,
                    ),
                  ),
                ],
              ),
            ),
            if (failure != null || _resent) ...[
              const SizedBox(height: 16),
              failure != null
                  ? AuthNote.failure(failure)
                  : AuthNote.info(l10n.codeResent),
            ],
            const SizedBox(height: 28),
            Directionality(
              textDirection: TextDirection.ltr,
              child: _Keypad(onKey: _onKey),
            ),
            const SizedBox(height: 24),
            ActionButton(
              label: _busy ? widget.busyAction : widget.action,
              onPressed: complete && !_busy
                  ? () => _call(() => widget.onDone(_digits))
                  : null,
            ),
            if (widget.onResend case final resend?)
              TextLink(
                label: l10n.resendCode,
                onTap: () {
                  if (!_busy) _call(resend, resend: true);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 1 to 9, then "+ 0 ⌫", 3 keys per row.
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['+', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, row) in _rows.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            children: [
              for (final (j, key) in row.indexed) ...[
                if (j > 0) const SizedBox(width: 12),
                Expanded(
                  child: _Key(label: key, onTap: () => onKey(key)),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.keypad);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white78,
        borderRadius: radius,
        boxShadow: AppShadows.key,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: 62,
            child: Center(
              child: SymbolText(label, style: AppTextStyles.keypad),
            ),
          ),
        ),
      ),
    );
  }
}
