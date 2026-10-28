// Sign-up, new user with a paid pack: pay now, or later (free until then).
// No real payment yet: both save the pack as "pending" (migration 005,
// choose_plan); the user keeps the free plan until it is paid.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/screen_title.dart';
import '../premium/payment_screen.dart';
import 'auth_messages.dart';
import 'pack_screen.dart';
import 'welcome_screen.dart';

class PaymentChoiceScreen extends StatefulWidget {
  const PaymentChoiceScreen({super.key, required this.plan});

  /// The paid pack chosen (essential or connected).
  final Plan plan;

  @override
  State<PaymentChoiceScreen> createState() => _PaymentChoiceScreenState();
}

class _PaymentChoiceScreenState extends State<PaymentChoiceScreen> {
  AuthFailure? _failure;
  bool _busy = false;

  /// "ادفع الآن": the design's payment screen, then the pack is saved.
  Future<void> _payNow() async {
    final confirmed = await openScreen<bool>(
      context,
      PaymentScreen(plan: widget.plan, forSignUp: true),
    );
    if (confirmed == true) await _save();
  }

  /// Saves the pack ("pending"), then the welcome screen.
  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      updateUser(await authService.choosePlan(widget.plan));
      if (mounted) replaceAllWith(context, const WelcomeScreen());
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
              title: l10n.payChoiceTitle,
              subtitle: l10n.payChoiceSubtitle,
              top: 64,
            ),
            // The pack and its price (like the payment screen's card).
            CssBox(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(34),
              shadows: AppShadows.card,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const IconBlob(icon: AppIcon.tree, size: 90, iconSize: 48),
                  const SizedBox(height: 14),
                  Text(
                    planName(l10n, widget.plan),
                    style: AppTextStyles.headline.copyWith(fontSize: 26),
                  ),
                  Text(
                    planPricePerMonth(l10n, widget.plan),
                    style: AppTextStyles.of(20, FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: 0.7,
                    child: Text(
                      l10n.payPendingNote,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.of(16, FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (failure != null) ...[
              const SizedBox(height: 16),
              AuthNote.failure(failure),
            ],
            const SizedBox(height: 24),
            ActionButton(
              label: '★ ${l10n.payNow}',
              onPressed: _busy ? null : _payNow,
            ),
            const SizedBox(height: 12),
            ActionButton(
              label: _busy ? l10n.saving : l10n.payLater,
              secondary: true,
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
