// "LOOZ بريميوم": what the free plan and Premium give, the price per zone
// (from the database), then:
//   - no orchard drawn yet: "ارسم بستانك" (the designer: draw, then pay);
//   - an orchard: the payment of its bill (a new month, or the extra zones).
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
import '../onboarding/auth_messages.dart';
import '../orchard_designer/designer_start_screen.dart';
import 'pack_texts.dart';
import 'payment_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _busy = false;
  String? _error;

  /// The bill of the orchard decides the next screen.
  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final quote = await paymentService.loadQuote();
      if (mounted) openScreen(context, PaymentScreen(quote: quote));
    } on PaymentError catch (error) {
      if (!mounted) return;
      if (error.failure == PaymentFailure.noDrawing) {
        openScreen(context, const DesignerStartScreen());
      } else {
        setState(
          () => _error = paymentFailureMessage(context.l10n, error.failure),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTextStyles.of(16);
    final bold = AppTextStyles.of(16, FontWeight.w700);
    final error = _error;
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
                      SymbolText('✓ ${l10n.packRegionalAlerts}', style: text),
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
                      SymbolText('✓ ${l10n.assistant}', style: text),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // The price of one zone.
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const _ZonePrice(),
              const SizedBox(height: 4),
              Text(
                l10n.packZoneNote,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(14.4),
              ),
              Text(
                l10n.cancelAnytime,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(14.4),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          AuthNote.error(error),
          const SizedBox(height: 12),
        ],
        ActionButton(
          label: _busy
              ? l10n.saving
              : '★ ${currentPlan.value == Plan.paid ? l10n.renewPack : l10n.startPremium}',
          onPressed: _busy ? null : _start,
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

/// "8 د.ت للمنطقة / 30 يومًا": the price of one zone, from the database.
class _ZonePrice extends StatefulWidget {
  const _ZonePrice();

  @override
  State<_ZonePrice> createState() => _ZonePriceState();
}

class _ZonePriceState extends State<_ZonePrice> {
  late final Future<PackPrice> _price = Future.sync(
    () => paymentService.loadPrice(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder(
      future: _price,
      builder: (context, snapshot) {
        final price = snapshot.data;
        // "…" while the price is read.
        return Text(
          price == null ? '…' : pricePerZoneText(l10n, price),
          textAlign: TextAlign.center,
          style: AppTextStyles.of(24, FontWeight.w700),
        );
      },
    );
  }
}
