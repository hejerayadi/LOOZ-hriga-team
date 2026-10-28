// Sign-up, new user: the choice of the pack (Free, Essential, Connected).
// The cards look like the plan card of the Premium screen: white, and the
// chosen one pale green with a green border.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/symbol_text.dart';
import 'auth_messages.dart';
import 'payment_choice_screen.dart';
import 'welcome_screen.dart';

/// The name of a pack, in the language of the app.
String planName(AppLocalizations l10n, Plan plan) => switch (plan) {
  Plan.free => l10n.free,
  Plan.essential => l10n.planEssential,
  Plan.connected => l10n.planConnected,
};

/// "XX د.ت / شهر" (paid packs).
String planPricePerMonth(AppLocalizations l10n, Plan plan) =>
    '${planPrice(plan)} ${l10n.pricePerMonth}';

class PackScreen extends StatefulWidget {
  const PackScreen({super.key});

  @override
  State<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends State<PackScreen> {
  Plan? _selected;
  AuthFailure? _failure;
  bool _busy = false;

  Future<void> _continue(Plan plan) async {
    if (plan != Plan.free) {
      // A paid pack: pay now or later (the pack is saved there).
      openScreen(context, PaymentChoiceScreen(plan: plan));
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      updateUser(await authService.choosePlan(Plan.free));
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
    final selected = _selected;
    final failure = _failure;
    final lines = {
      Plan.free: [
        l10n.tabCommunity,
        l10n.packAssistantLimit('$freeAssistantQuestionsPerDay'),
        l10n.packRegionalAlerts,
      ],
      Plan.essential: [
        l10n.packAllOfFree,
        l10n.packUnlimitedAssistant,
        l10n.pack3dOrchard,
        l10n.packPhotoDiagnosis,
      ],
      Plan.connected: [
        l10n.packAllOfEssential,
        l10n.packLiveSensors,
        l10n.smartAlerts,
        l10n.packPredictions,
      ],
    };
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
            ScreenTitle(title: l10n.packTitle, subtitle: l10n.packSubtitle),
            for (final plan in Plan.values) ...[
              _PackCard(
                name: planName(l10n, plan),
                price: plan == Plan.free
                    ? l10n.packNoPayment
                    : planPricePerMonth(l10n, plan),
                lines: lines[plan]!,
                selected: plan == selected,
                onTap: _busy ? null : () => setState(() => _selected = plan),
              ),
              const SizedBox(height: 12),
            ],
            if (failure != null) ...[
              const SizedBox(height: 4),
              AuthNote.failure(failure),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            ActionButton(
              label: _busy ? l10n.saving : l10n.continueLabel,
              onPressed: selected == null || _busy
                  ? null
                  : () => _continue(selected),
            ),
          ],
        ),
      ),
    );
  }
}

/// One pack: its name and price, then what it gives ("✓ ...").
class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.name,
    required this.price,
    required this.lines,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String price;
  final List<String> lines;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTextStyles.of(16);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          color: selected ? AppColors.mintWhite : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          shadows: AppShadows.card,
          // Always 2 px, so the card does not move when it is chosen.
          border: Border.all(
            color: selected ? AppColors.midGreen : AppColors.white,
            width: 2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, style: AppTextStyles.cardTitle),
                  ),
                  const SizedBox(width: 12),
                  Text(price, style: AppTextStyles.of(16, FontWeight.w700)),
                ],
              ),
              for (final line in lines) ...[
                const SizedBox(height: 4),
                SymbolText('✓ $line', style: text),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
