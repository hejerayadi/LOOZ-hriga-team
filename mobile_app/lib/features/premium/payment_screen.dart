// "الدفع": the price and a card, then "★ تأكيد".
//
// DEMO: nothing is paid. The card fields show the design's example, and
// "تأكيد" turns the (fake) plan into Premium.
// At the sign-up ("ادفع الآن"), "تأكيد" goes back to the sign-up, which
// saves the pack as "pending" (no tab bar there: the app is not open yet).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/theme/app_theme.dart';
import '../../data/fake_data.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import 'qr_screen.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({
    super.key,
    this.plan = Plan.connected,
    this.forSignUp = false,
  });

  /// The pack paid (its price is shown). Premium = the biggest pack.
  final Plan plan;

  /// true = opened by the sign-up: "تأكيد" closes it with the result true.
  final bool forSignUp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final field = AppTextStyles.of(19);
    Widget box(String text, {bool center = true}) => Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: center ? Alignment.center : AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: AppColors.mintWhite,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text, style: field),
    );
    return ShellPage(
      showBars: !forSignUp,
      children: [
        ScreenTitle(title: l10n.paymentTitle, subtitle: l10n.paymentSubtitle),
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(34),
          shadows: AppShadows.card,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            children: [
              const IconBlob(icon: AppIcon.user, size: 90, iconSize: 48),
              const SizedBox(height: 20),
              Text(
                '${planPrice(plan)} ${l10n.pricePerMonth}',
                style: AppTextStyles.of(26, FontWeight.w700),
              ),
              const SizedBox(height: 20),
              box(fakeCardNumber, center: false),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: box(fakeCardExpiry)),
                  const SizedBox(width: 12),
                  Expanded(child: box(fakeCardCode)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ActionButton(
          label: '★ ${l10n.confirm}',
          onPressed: () {
            if (forSignUp) {
              Navigator.of(context).pop(true);
              return;
            }
            currentPlan.value = Plan.connected;
            openScreen(context, const QrScreen());
          },
        ),
      ],
    );
  }
}
