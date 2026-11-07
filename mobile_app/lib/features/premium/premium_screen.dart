// "LOOZ بريميوم": what the free plan and Premium give, the price (the
// smallest paid pack, from the database), then the paid packs.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/theme/app_theme.dart';
import '../../data/payment_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/orchard_scene.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/symbol_text.dart';
import '../../shared/widgets/text_link.dart';
import '../onboarding/pack_screen.dart';
import 'pack_texts.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTextStyles.of(16);
    final bold = AppTextStyles.of(16, FontWeight.w700);
    return ShellPage(
      children: [
        // The drawing with a gold star and the title.
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(34),
          shadows: AppShadows.card,
          clip: true,
          padding: const EdgeInsets.only(bottom: 18),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OrchardScene(radius: 0),
                  const SizedBox(height: 14),
                  Text(
                    l10n.premiumTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headline,
                  ),
                ],
              ),
              // On the left in both languages, like in the design.
              Positioned(
                top: 20,
                left: 20,
                child: SymbolText(
                  '★',
                  style: AppTextStyles.of(40)
                      .copyWith(color: AppColors.midGreen),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Free | Premium.
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          shadows: AppShadows.card,
          padding: const EdgeInsets.all(8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 10,
                  child: _PlanColumn(
                    title: Text(l10n.free, style: bold),
                    lines: [
                      SymbolText('✓ ${l10n.tabCommunity}', style: text),
                      SymbolText('✓ ${l10n.assistant}', style: text),
                    ],
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: _PlanColumn(
                    premium: true,
                    title: SymbolText(l10n.premiumName, style: bold),
                    lines: [
                      SymbolText('✓ ${l10n.orchardMap}', style: text),
                      SymbolText('✓ ${l10n.smartAlerts}', style: text),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // The price.
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const _EntryPrice(),
              Text(
                l10n.cancelAnytime,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(14.4),
              ),
            ],
          ),
        ),
        ActionButton(
          label: '★ ${l10n.startPremium}',
          onPressed: () => openScreen(context, const PackScreen(upgrade: true)),
        ),
        TextLink(
          label: l10n.notNow,
          onTap: () => goToTab(context, AppTab.orchard),
        ),
      ],
    );
  }
}

/// One column of the plan card (Premium: pale green, gold border).
class _PlanColumn extends StatelessWidget {
  const _PlanColumn({
    required this.title,
    required this.lines,
    this.premium = false,
  });

  final Widget title;
  final List<Widget> lines;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    return CssBox(
      color: premium ? AppColors.mintWhite : null,
      borderRadius: BorderRadius.circular(premium ? 22 : 0),
      border: premium ? Border.all(color: AppColors.midGreen, width: 2) : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          for (final line in lines) ...[const SizedBox(height: 10), line],
        ],
      ),
    );
  }
}

/// "15 د.ت / 30 يومًا": the price of Essential, the smallest paid pack.
class _EntryPrice extends StatefulWidget {
  const _EntryPrice();

  @override
  State<_EntryPrice> createState() => _EntryPriceState();
}

class _EntryPriceState extends State<_EntryPrice> {
  late final Future<Map<Plan, PackPrice>> _prices = Future.sync(
    () => paymentService.loadPrices(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder(
      future: _prices,
      builder: (context, snapshot) {
        final price = snapshot.data?[Plan.essential];
        // "…" while the price is read.
        final amount = price == null ? '…' : dinars(price.millimes);
        final period = price == null ? l10n.month : l10n.daysCount(price.days);
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$amount ${l10n.currency}',
                style: AppTextStyles.of(28, FontWeight.w700),
              ),
              TextSpan(text: ' / $period'),
            ],
          ),
          textAlign: TextAlign.center,
          style: AppTextStyles.of(18),
        );
      },
    );
  }
}
