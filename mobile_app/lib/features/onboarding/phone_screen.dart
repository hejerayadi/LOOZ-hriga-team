// Login, step 1 and 2: the phone number, then the code "sent by SMS".
//
// DEMO: no SMS is sent and any 6-digit code works. The real login
// (Supabase, lib/features/auth/) is kept in the project for later.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/fake_data.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/symbol_text.dart';
import 'welcome_screen.dart';

/// Step 1: the phone number (8 digits after +216).
class PhoneScreen extends StatelessWidget {
  const PhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final length = phoneGroups.reduce((a, b) => a + b);
    return _KeypadScreen(
      title: l10n.phoneTitle,
      subtitle: l10n.phoneSubtitle,
      action: l10n.sendCode,
      length: length,
      // "+216 12 345 •••": the digits typed, then dots for the missing ones.
      display: (digits) {
        final slots = digits.padRight(length, '•');
        final groups = <String>[];
        var start = 0;
        for (final size in phoneGroups) {
          groups.add(slots.substring(start, start + size));
          start += size;
        }
        return '$phonePrefix ${groups.join(' ')}';
      },
      onDone: (_) => openScreen(context, const CodeScreen()),
    );
  }
}

/// Step 2: the code (any 6 digits, it's a demo).
class CodeScreen extends StatelessWidget {
  const CodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _KeypadScreen(
      title: l10n.codeTitle,
      subtitle: l10n.codeSubtitle,
      action: l10n.confirm,
      length: demoCodeLength,
      // "1 2 • • • •"
      display: (digits) =>
          digits.padRight(demoCodeLength, '•').split('').join(' '),
      onDone: (_) => openScreen(context, const WelcomeScreen()),
    );
  }
}

/// The layout of both steps: title, the number, a keypad and the button.
class _KeypadScreen extends StatefulWidget {
  const _KeypadScreen({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.length,
    required this.display,
    required this.onDone,
  });

  final String title;
  final String subtitle;

  /// Text of the big button.
  final String action;

  /// How many digits are needed.
  final int length;

  /// The text shown above the keypad, from the digits typed.
  final String Function(String digits) display;

  /// Called with the digits when the button is tapped.
  final ValueChanged<String> onDone;

  @override
  State<_KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<_KeypadScreen> {
  String _digits = '';

  void _onKey(String key) {
    setState(() {
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

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.paddingOf(context);
    final complete = _digits.length == widget.length;
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
                  const SizedBox(height: 28),
                  _Keypad(onKey: _onKey),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ActionButton(
              label: widget.action,
              onPressed: complete ? () => widget.onDone(_digits) : null,
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
