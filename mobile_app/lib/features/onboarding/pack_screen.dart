// The choice of the pack, with the prices of the database (plan_prices):
//   Free (never pays), Essential (15 DT / 30 days: the demo payment),
//   Connected (8 DT per sensor / 30 days: it needs the LOOZ sensor kit
//   first: choosing it asks for the kit, the user stays on Free until the
//   kit is installed; then he pays from Premium / Profile).
// At the sign-up (farmers only) and from Premium ("upgrade": paid packs).
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
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/symbol_text.dart';
import '../premium/kit_requested_screen.dart';
import '../premium/pack_texts.dart';
import '../premium/payment_screen.dart';
import 'auth_messages.dart';
import 'welcome_screen.dart';

class PackScreen extends StatefulWidget {
  const PackScreen({super.key, this.upgrade = false});

  /// false = the sign-up (Free, Essential, Connected); true = from Premium
  /// or Profile, the app is open (the paid packs only).
  final bool upgrade;

  @override
  State<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends State<PackScreen> {
  Map<Plan, PackPrice>? _prices;

  /// The LOOZ kit of the user (upgrade only: a new user has none).
  KitRequest? _kit;

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
      final prices = await Future.sync(() => paymentService.loadPrices());
      final kit = widget.upgrade ? await paymentService.loadKit() : null;
      if (mounted) {
        setState(() {
          _prices = prices;
          _kit = kit;
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
      switch (plan) {
        case Plan.free:
          updateUser(await authService.choosePlan(Plan.free));
          if (mounted) replaceAllWith(context, const WelcomeScreen());
        case Plan.essential:
          // Saved as "pending": if the app closes, the payment comes back.
          if (!widget.upgrade) {
            updateUser(await authService.choosePlan(Plan.essential));
          }
          if (mounted) {
            openScreen(
              context,
              PaymentScreen(plan: Plan.essential, signUp: !widget.upgrade),
            );
          }
        case Plan.connected:
          final kit = _kit;
          if (kit != null && kit.installed) {
            // The kit works: 8 DT x its sensors.
            openScreen(
              context,
              PaymentScreen(plan: Plan.connected, sensors: kit.sensors),
            );
          } else {
            // No kit yet: we install it first. Meanwhile: the free plan.
            final request = await paymentService.requestKit();
            if (!widget.upgrade) {
              updateUser(await authService.choosePlan(Plan.free));
            }
            if (!mounted) return;
            setState(() => _kit = request);
            final screen = KitRequestedScreen(signUp: !widget.upgrade);
            widget.upgrade
                ? openScreen(context, screen)
                : replaceAllWith(context, screen);
          }
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prices = _prices;
    final selected = _selected;
    final error = _error;
    final kit = _kit;
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
    String price(Plan plan) {
      final p = prices?[plan];
      if (plan == Plan.free) return l10n.packNoPayment;
      if (p == null) return '…';
      return kit != null && kit.installed && plan == Plan.connected
          ? priceText(l10n, p, sensors: kit.sensors)
          : priceText(l10n, p);
    }

    final children = [
      ScreenTitle(title: l10n.packTitle, subtitle: l10n.packSubtitle),
      for (final plan in Plan.values)
        if (plan != Plan.free || !widget.upgrade) ...[
          _PackCard(
            icon: switch (plan) {
              Plan.free => AppIcon.people,
              Plan.essential => AppIcon.leaf,
              Plan.connected => AppIcon.wifi,
            },
            name: planName(l10n, plan),
            price: price(plan),
            lines: lines[plan]!,
            note: plan != Plan.connected
                ? null
                : kit != null && kit.installed
                ? l10n.kitSensors(kit.sensors!)
                : l10n.packConnectedKit,
            selected: plan == selected,
            onTap: _busy ? null : () => setState(() => _selected = plan),
          ),
          const SizedBox(height: 12),
        ],
      if (error != null) ...[
        const SizedBox(height: 4),
        AuthNote.error(error),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 12),
      ActionButton(
        label: _busy ? l10n.saving : l10n.continueLabel,
        onPressed: selected == null || _busy || prices == null
            ? (prices == null && error != null ? _load : null)
            : () => _continue(selected),
      ),
    ];
    // From Premium: inside the app (bars at the bottom).
    if (widget.upgrade) return ShellPage(children: children);
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
          children: [const LoozHeader(), ...children],
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

  /// Under the lines (Connected: the LOOZ kit).
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
