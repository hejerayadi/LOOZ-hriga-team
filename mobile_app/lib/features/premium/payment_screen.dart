// "الدفع" (the design's payment screen): Premium and the bill of the
// orchard (made by the database: its zones x the price of a zone, or only
// the extra zones until the end of the period), the card, then "★ تأكيد"
// → "جاري التحقق من الدفع…" (about 2 seconds) → paid (with the end date) or
// not paid (payment_result_screen.dart).
//
// DEMO PAYMENT: no real money. The card fields (demo_card_form.dart) are
// only checked on the phone, then cleared: they are never saved nor sent.
// A small "وضع تجريبي" label says it. The database gives the pack only
// while demo payments are on (an admin can turn them off).
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
import 'demo_card_form.dart';
import 'pack_texts.dart';
import 'payment_result_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.quote, this.signUp = false});

  /// The bill of the orchard (orchard_quote() of the database).
  final OrchardQuote quote;

  /// true = during the sign-up (no tab bar: the app is not open yet).
  final bool signUp;

  /// How long "جاري التحقق من الدفع…" stays (at least).
  static const checkingTime = Duration(seconds: 2);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _card = GlobalKey<DemoCardFormState>();
  bool _checking = false;

  Future<void> _pay() async {
    final card = _card.currentState;
    if (card == null || !card.validate()) return;
    // Only "accepted or not" leaves the form; the card is forgotten now.
    final accepted = card.accepted;
    card.clear();
    setState(() => _checking = true);
    PaymentResult? result;
    PaymentFailure? failure;
    Future<void> payNow() async {
      try {
        result = await paymentService.pay(cardAccepted: accepted);
      } catch (error) {
        failure = paymentFailureOf(error);
      }
    }

    await Future.wait([
      Future<void>.delayed(PaymentScreen.checkingTime),
      payNow(),
    ]);
    if (result?.paid ?? false) await _refreshPlan();
    if (!mounted) return;
    setState(() => _checking = false);
    openScreen(
      context,
      PaymentResultScreen(
        paid: result?.paid ?? false,
        signUp: widget.signUp,
        endsAt: result?.endsAt,
        failure: failure,
      ),
    );
  }

  /// The pack is paid: the app opens what it gives at once.
  Future<void> _refreshPlan() async {
    try {
      currentPlan.value = await authService.loadPlan();
      updateUser(await authService.loadProfile());
    } catch (_) {
      currentPlan.value = Plan.paid; // read again at the next start
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final quote = widget.quote;
    final endsAt = quote.endsAt;
    return ShellPage(
      showBars: !widget.signUp,
      children: [
        ScreenTitle(title: l10n.paymentTitle, subtitle: l10n.paymentSubtitle),
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(34),
          shadows: AppShadows.card,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            children: [
              if (paymentService.isDemo) ...[
                const _DemoLabel(),
                const SizedBox(height: 10),
              ],
              const IconBlob(icon: AppIcon.user, size: 90, iconSize: 48),
              const SizedBox(height: 16),
              Text(
                planName(l10n, Plan.paid),
                style: AppTextStyles.of(20, FontWeight.w700),
              ),
              Text(
                payNowText(l10n, quote),
                textAlign: TextAlign.center,
                style: AppTextStyles.of(26, FontWeight.w700),
              ),
              // Why this price: "4 مناطق" (and the extra zones: until when).
              Text(
                quote.kind == QuoteKind.extraZones && endsAt != null
                    ? '${l10n.zonesCount(quote.billedZones)} · '
                          '${l10n.planUntil(dayText(endsAt))}'
                    : l10n.zonesCount(quote.billedZones),
                textAlign: TextAlign.center,
                style: AppTextStyles.of(17, FontWeight.w700),
              ),
              const SizedBox(height: 20),
              DemoCardForm(key: _card),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ActionButton(
          label: _checking ? l10n.checkingPayment : '★ ${l10n.confirm}',
          onPressed: _checking ? null : _pay,
        ),
      ],
    );
  }
}

/// "وضع تجريبي / Mode démo": small and discreet, at the top of the card.
class _DemoLabel extends StatelessWidget {
  const _DemoLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        context.l10n.demoMode,
        style: AppTextStyles.of(13, FontWeight.w700),
      ),
    );
  }
}
