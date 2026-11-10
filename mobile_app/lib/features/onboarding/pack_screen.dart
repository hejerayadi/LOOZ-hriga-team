// The choice of the pack at the sign-up (farmers only), with the price of
// the database (plan_prices):
//   مجاني / Gratuit:   community and regional alerts, never pays;
//   بريميوم / Premium: 8 DT per zone of the orchard / 30 days. The farmer
//                      draws his orchard first (the designer), then pays.
// The cards look like the plan card of the Premium screen: white, and the
// chosen one pale green with a green border.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';
import '../../data/payment_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/symbol_text.dart';
import '../orchard_designer/designer_start_screen.dart';
import '../premium/pack_texts.dart';
import 'auth_messages.dart';
import 'welcome_screen.dart';

class PackScreen extends StatefulWidget {
  const PackScreen({super.key});

  @override
  State<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends State<PackScreen> {
  PackPrice? _price;
  Plan? _selected;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // (Future.sync: even an error at once arrives after initState.)
      final price = await Future.sync(() => paymentService.loadPrice());
      if (mounted) {
        setState(() {
          _price = price;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  String _message(Object error) => error is AuthError
      ? failureMessage(context.l10n, error.failure)
      : paymentFailureMessage(context.l10n, paymentFailureOf(error));

  Future<void> _continue(Plan plan) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Premium is saved as "pending": the farmer has the free plan until he
      // has drawn his orchard and paid (if the app closes, the designer
      // comes back at the next login).
      updateUser(await authService.choosePlan(plan));
      if (!mounted) return;
      replaceAllWith(
        context,
        plan == Plan.free
            ? const WelcomeScreen()
            : const DesignerStartScreen(signUp: true),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = _price;
    final selected = _selected;
    final error = _error;
    final system = MediaQuery.paddingOf(context);
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
            _PackCard(
              icon: AppIcon.people,
              name: l10n.free,
              price: l10n.packNoPayment,
              lines: [l10n.tabCommunity, l10n.packRegionalAlerts],
              selected: selected == Plan.free,
              onTap: _busy ? null : () => setState(() => _selected = Plan.free),
            ),
            const SizedBox(height: 12),
            _PackCard(
              icon: AppIcon.tree,
              name: l10n.planPaid,
              price: price == null ? '…' : pricePerZoneText(l10n, price),
              lines: [
                l10n.packAllOfFree,
                l10n.pack3dOrchard,
                l10n.packPredictions,
                l10n.packPhotoDiagnosis,
                l10n.packVoiceAssistant,
              ],
              note: l10n.packZoneNote,
              selected: selected == Plan.paid,
              onTap: _busy ? null : () => setState(() => _selected = Plan.paid),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              AuthNote.error(error),
            ],
            const SizedBox(height: 24),
            ActionButton(
              label: _busy ? l10n.saving : l10n.continueLabel,
              onPressed: selected == null || _busy || price == null
                  ? (price == null && error != null ? _load : null)
                  : () => _continue(selected),
            ),
          ],
        ),
      ),
    );
  }
}

/// One pack: its icon, name and price, then what it gives ("✓ ...").
class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.icon,
    required this.name,
    required this.price,
    required this.lines,
    required this.selected,
    required this.onTap,
    this.note,
  });

  final AppIcon icon;
  final String name;
  final String price;
  final List<String> lines;

  /// Under the lines (Premium: one sensor per zone).
  final String? note;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTextStyles.of(16);
    final note = this.note;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBlob(icon: icon, size: 50, iconSize: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.cardTitle),
                        Text(
                          price,
                          style: AppTextStyles.of(16, FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (selected) const LoozIcon(AppIcon.check, size: 24),
                ],
              ),
              const SizedBox(height: 6),
              for (final line in lines) ...[
                const SizedBox(height: 4),
                SymbolText('✓ $line', style: text),
              ],
              if (note != null) ...[
                const SizedBox(height: 8),
                Text(note, style: AppTextStyles.of(15, FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
