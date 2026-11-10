// After the payment (not in the design: the app's own screen, in its style):
//   paid: "تم الدفع!" and the end date of the pack, then the sign-up goes
//         on (welcome), in the app the design's QR screen ("مرحبًا في
//         بريميوم": scan the box of your orchard); paid from the designer:
//         the orchard is built ("جاري بناء بستانك…"), then the 3D;
//   not paid: "لم يكتمل الدفع", the user stays on the free plan:
//         "حاول مرة أخرى" or "متابعة مجانًا".
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/payment_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../onboarding/welcome_screen.dart';
import '../orchard_designer/build_orchard_screen.dart';
import 'pack_texts.dart';
import 'qr_screen.dart';

class PaymentResultScreen extends StatefulWidget {
  const PaymentResultScreen({
    super.key,
    required this.paid,
    this.signUp = false,
    this.endsAt,
    this.failure,
    this.buildOrchard = false,
  });

  final bool paid;
  final bool signUp;

  /// true = paid from the designer: the orchard is built next.
  final bool buildOrchard;

  /// The end of the pack (paid).
  final DateTime? endsAt;

  /// Why it was not paid, when it is not the card (no internet...).
  final PaymentFailure? failure;

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  bool _busy = false;

  /// Paid: the next screen.
  void _continue() {
    if (widget.buildOrchard) {
      replaceWith(context, BuildOrchardScreen(signUp: widget.signUp));
    } else if (widget.signUp) {
      replaceAllWith(context, const WelcomeScreen());
    } else {
      replaceWith(
        context,
        const QrScreen(),
      ); // the design's "مرحبًا في بريميوم"
    }
  }

  /// Not paid: go on with the free plan.
  Future<void> _continueFree() async {
    if (!widget.signUp) {
      goToTab(context, AppTab.home);
      return;
    }
    setState(() => _busy = true);
    try {
      updateUser(await authService.choosePlan(Plan.free));
    } catch (_) {
      // Not saved (no internet): the next login shows the packs again.
    }
    if (mounted) replaceAllWith(context, const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final paid = widget.paid;
    final endsAt = widget.endsAt;
    final failure = widget.failure;
    return ShellPage(
      showBars: !widget.signUp,
      children: [
        ScreenTitle(title: paid ? l10n.paidTitle : l10n.notPaidTitle),
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(34),
          shadows: AppShadows.card,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Semantics(
            liveRegion: true,
            child: Column(
              children: [
                IconBlob(
                  // (Not the bug: on a farm it would mean a pest.)
                  icon: paid ? AppIcon.check : AppIcon.card,
                  color: paid ? AppColors.mint : AppColors.peach,
                  size: 90,
                  iconSize: 48,
                ),
                const SizedBox(height: 18),
                Text(
                  planName(l10n, Plan.paid),
                  style: AppTextStyles.of(22, FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (paid && endsAt != null)
                  Text(
                    l10n.paidUntil(dayText(endsAt)),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.of(19, FontWeight.w700),
                  ),
                if (!paid) ...[
                  if (failure != null) ...[
                    Text(
                      paymentFailureMessage(l10n, failure),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.of(18, FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    l10n.notPaidText,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.of(17),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (paid)
          ActionButton(label: l10n.continueLabel, onPressed: _continue)
        else ...[
          ActionButton(
            label: l10n.tryAgain,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 12),
          ActionButton(
            label: l10n.continueFree,
            secondary: true,
            onPressed: _busy ? null : _continueFree,
          ),
        ],
      ],
    );
  }
}
