// Step 3 of the designer: the review. The draft is saved (step "review"),
// so the database makes the bill from it (orchard_quote): the area, the
// zones, the trees, the sensors billed (at least 1 per 2 ha: said in one
// sentence when it applies) and the price for 30 days. Then:
//   "★ ادفع وابنِ بستاني" → the demo payment → the orchard is built → 3D;
//   the pack already covers it: "★ ابنِ بستاني" (no payment).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/zone_letters.dart';
import '../../data/payment_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/text_link.dart';
import '../onboarding/welcome_screen.dart';
import '../premium/pack_texts.dart';
import '../premium/payment_screen.dart';
import 'build_orchard_screen.dart';
import 'design_session.dart';
import 'designer_widgets.dart';
import 'geometry.dart';
import 'orchard_canvas.dart';

/// The most sensors one pack can have (the database: 1 to 100).
const maxBilledSensors = 100;

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.session});

  final DesignSession session;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Future<OrchardQuote> _quote = _load();
  bool _busy = false;

  Future<OrchardQuote> _load() => Future.sync(paymentService.loadQuote);

  /// Sign-up: the free plan for now (the drawing stays saved).
  Future<void> _continueFree() async {
    setState(() => _busy = true);
    try {
      updateUser(await authService.choosePlan(Plan.free));
    } catch (_) {
      // Not saved (no internet): the next login shows the designer again.
    }
    if (mounted) replaceAllWith(context, const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = widget.session;
    return FutureBuilder(
      future: _quote,
      builder: (context, snapshot) {
        final quote = snapshot.data;
        final error = snapshot.error;
        final List<Widget> bottom;
        // Under the bill (it scrolls): only the main button stays at the
        // bottom, so the price is seen before paying.
        final links = <Widget>[];
        if (quote == null) {
          bottom = [
            if (error != null)
              ActionButton(
                label: l10n.tryAgain,
                onPressed: () => setState(() {
                  _quote = _load();
                }),
              ),
          ];
        } else if (quote.billedZones > maxBilledSensors) {
          bottom = [
            HintLine(l10n.orchardTooBig, problem: true),
            TextLink(
              label: l10n.editZones,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ];
        } else {
          final covered = quote.kind == QuoteKind.covered;
          bottom = [
            ActionButton(
              label: covered
                  ? '★ ${l10n.buildMyOrchard}'
                  : '★ ${l10n.payAndBuild}',
              onPressed: _busy
                  ? null
                  : () => openScreen(
                      context,
                      covered
                          ? BuildOrchardScreen(signUp: session.signUp)
                          : PaymentScreen(
                              quote: quote,
                              signUp: session.signUp,
                              buildOrchard: true,
                            ),
                    ),
            ),
          ];
          links.addAll([
            TextLink(
              label: l10n.editZones,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            if (session.signUp)
              TextLink(
                label: l10n.continueFree,
                onTap: _busy ? () {} : _continueFree,
              ),
          ]);
        }
        return DesignerPage(
          step: 3,
          title: l10n.reviewTitle,
          hint: HintLine(l10n.reviewSubtitle),
          body: ListView(
            children: [
              CanvasCard(
                height: MediaQuery.sizeOf(context).height < 700 ? 140 : 170,
                child: OrchardCanvas(
                  frame: frameAround(session.design.outline),
                  semanticLabel: l10n.a11yOrchardDrawing,
                  outline: session.design.outline,
                  zones: [
                    for (final z in session.design.zones)
                      CanvasZone(
                        letter: zoneLetterOf(context, z.letter),
                        boundary: z.boundary,
                        color: z.color,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (quote != null)
                _Bill(session: session, quote: quote)
              else if (error != null)
                HintLine(
                  paymentFailureMessage(l10n, paymentFailureOf(error)),
                  problem: true,
                )
              else
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ...links,
            ],
          ),
          bottom: bottom,
        );
      },
    );
  }
}

/// The card of the bill: area, zones, trees, sensors, price.
class _Bill extends StatelessWidget {
  const _Bill({required this.session, required this.quote});

  final DesignSession session;
  final OrchardQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final design = session.design;
    final trees = design.zones.fold(0, (s, z) => s + (z.treeCount ?? 0));
    final area = hectares(design.outline).toStringAsFixed(2);
    final byArea = quote.billedZones > quote.zones;
    final extra = quote.kind == QuoteKind.extraZones;
    Widget row(AppIcon icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          IconBlob(icon: icon, size: 44, iconSize: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTextStyles.of(17, FontWeight.w700)),
          ),
          Text(value, style: AppTextStyles.of(18, FontWeight.w800)),
        ],
      ),
    );
    return CssBox(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      shadows: AppShadows.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(AppIcon.ruler, l10n.areaLabel, l10n.hectaresValue(area)),
          row(AppIcon.map, l10n.zonesLabel, l10n.zonesCount(quote.zones)),
          row(AppIcon.tree, l10n.treesLabel, l10n.treeCount('$trees')),
          row(
            AppIcon.wifi,
            l10n.sensorsLabel,
            l10n.sensorsCount(quote.billedZones),
          ),
          // Why more sensors than zones (one simple sentence + a tip).
          if (byArea) ...[
            const SizedBox(height: 6),
            CssBox(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              padding: const EdgeInsets.all(12),
              child: Text(
                '${l10n.areaMinimum(area, l10n.sensorsCount(quote.billedZones))} '
                '${l10n.areaMinimumTip(l10n.zonesCount(quote.billedZones))}',
                style: AppTextStyles.of(16, FontWeight.w700),
              ),
            ),
          ],
          const Divider(height: 22),
          // The price on its own line (big, never cut).
          Row(
            children: [
              IconBlob(
                icon: AppIcon.card,
                size: 44,
                iconSize: 22,
                color: AppColors.mint,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.priceLabel,
                style: AppTextStyles.of(17, FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            quote.kind == QuoteKind.covered
                ? l10n.packCovers
                : payNowText(l10n, quote),
            textAlign: TextAlign.center,
            style: AppTextStyles.of(
              quote.kind == QuoteKind.covered ? 19 : 24,
              FontWeight.w800,
            ),
          ),
          if (extra)
            Text(
              l10n.thenPrice(
                l10n.priceForDays(
                  dinars(quote.monthlyMillimes),
                  l10n.daysCount(quote.days),
                ),
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.of(15, FontWeight.w700),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
