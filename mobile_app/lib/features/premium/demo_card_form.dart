// DEMO PAYMENT ONLY: the card fields of the design's payment screen.
//
// They only LOOK real: the card is checked here (16 digits, a date that is
// not past, 3 digits, a name), then cleared. It is NEVER saved, sent (not
// to Supabase, not anywhere), printed or written in a log. The only thing
// that leaves this form is "accepted or not": the test card
// 4000 0000 0000 0002 is always refused (to show the "not paid" screen).
//
// A real payment provider later: its secure page replaces this form (see
// lib/data/payment_service.dart); the payment screen around stays.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validators.dart';
import '../../shared/widgets/app_icon.dart';
import '../onboarding/auth_messages.dart';

/// The test card that is always refused.
const demoRefusedCard = '4000000000000002';

class DemoCardForm extends StatefulWidget {
  const DemoCardForm({super.key});

  @override
  DemoCardFormState createState() => DemoCardFormState();
}

class DemoCardFormState extends State<DemoCardForm> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _checked = false;

  static String _digits(TextEditingController box) =>
      box.text.replaceAll(RegExp('[^0-9]'), '');

  bool get _numberOk => _digits(_number).length == 16;

  bool get _expiryOk {
    final digits = _digits(_expiry);
    if (digits.length != 4) return false;
    final month = int.parse(digits.substring(0, 2));
    final year = 2000 + int.parse(digits.substring(2));
    final now = DateTime.now();
    return month >= 1 &&
        month <= 12 &&
        (year > now.year || (year == now.year && month >= now.month));
  }

  bool get _codeOk => _digits(_code).length == 3;

  /// Shows what is wrong under the boxes; true = the card looks right.
  bool validate() {
    setState(() => _checked = true);
    return _numberOk && _expiryOk && _codeOk && checkName(_name.text) == null;
  }

  /// The demo answer: false only for the test card that is always refused.
  bool get accepted => _digits(_number) != demoRefusedCard;

  /// Forgets the card (after "pay", and when the screen closes).
  void clear() {
    for (final box in [_number, _expiry, _code, _name]) {
      box.clear();
    }
    setState(() => _checked = false);
  }

  @override
  void dispose() {
    for (final box in [_number, _expiry, _code, _name]) {
      box
        ..clear()
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nameProblem = _checked ? checkName(_name.text) : null;
    void changed() {
      if (_checked) setState(() {});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardBox(
          icon: AppIcon.card,
          hint: l10n.cardNumber,
          controller: _number,
          error: _checked && !_numberOk ? l10n.cardNumberInvalid : null,
          numbers: true,
          formatters: [const _DigitsFormatter(max: 16, group: 4)],
          onChanged: changed,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CardBox(
                icon: AppIcon.clock,
                hint: l10n.cardExpiry,
                controller: _expiry,
                error: _checked && !_expiryOk ? l10n.cardExpiryInvalid : null,
                numbers: true,
                formatters: [
                  const _DigitsFormatter(max: 4, group: 2, separator: '/'),
                ],
                onChanged: changed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CardBox(
                icon: AppIcon.lock,
                hint: l10n.cardCode,
                controller: _code,
                error: _checked && !_codeOk ? l10n.cardCodeInvalid : null,
                numbers: true,
                hidden: true,
                formatters: [const _DigitsFormatter(max: 3)],
                onChanged: changed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CardBox(
          icon: AppIcon.user,
          hint: l10n.cardName,
          controller: _name,
          error: nameProblem == null
              ? null
              : nameProblemMessage(l10n, nameProblem),
          formatters: [LengthLimitingTextInputFormatter(nameMaxLength)],
          onChanged: changed,
        ),
      ],
    );
  }
}

/// One box of the card (the design's pale boxes), with its icon, and what
/// is wrong under it.
class _CardBox extends StatelessWidget {
  const _CardBox({
    required this.icon,
    required this.hint,
    required this.controller,
    required this.formatters,
    required this.onChanged,
    this.error,
    this.numbers = false,
    this.hidden = false,
  });

  final AppIcon icon;
  final String hint;
  final TextEditingController controller;
  final List<TextInputFormatter> formatters;
  final VoidCallback onChanged;
  final String? error;

  /// Digits, written left to right (also in Arabic).
  final bool numbers;

  /// The security code: shown as dots.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final style = AppTextStyles.of(19, FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.mintWhite,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: error != null ? AppColors.danger : AppColors.mintWhite,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              LoozIcon(icon, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: style,
                  cursorColor: AppColors.green,
                  obscureText: hidden,
                  enableSuggestions: false,
                  autocorrect: false,
                  // Never offered to the phone's autofill or saved.
                  autofillHints: const [],
                  keyboardType: numbers
                      ? TextInputType.number
                      : TextInputType.name,
                  textDirection: numbers ? TextDirection.ltr : null,
                  textCapitalization: numbers
                      ? TextCapitalization.none
                      : TextCapitalization.characters,
                  // The box draws its own line: none of the theme inside it
                  // (not even while typing).
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: hint,
                    hintStyle: AppTextStyles.of(16)
                        .copyWith(color: AppColors.textMuted),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  inputFormatters: formatters,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, top: 4),
            child: Text(
              error,
              style: AppTextStyles.of(
                14,
                FontWeight.w700,
              ).copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

/// Keeps only digits (also from an Arabic keyboard), at most [max], with
/// [separator] every [group] digits ("4000 0000 ...", "08/28").
class _DigitsFormatter extends TextInputFormatter {
  const _DigitsFormatter({
    required this.max,
    this.group = 0,
    this.separator = ' ',
  });

  final int max;
  final int group;
  final String separator;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue value,
  ) {
    var digits = westernDigits(value.text).replaceAll(RegExp('[^0-9]'), '');
    if (digits.length > max) digits = digits.substring(0, max);
    final text = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (group > 0 && i > 0 && i % group == 0) text.write(separator);
      text.write(digits[i]);
    }
    final result = text.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
