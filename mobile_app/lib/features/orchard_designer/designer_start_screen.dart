// "ارسم بستانك": the first screen of the orchard designer (paid pack).
// The price of Premium depends on the zones of the orchard, so the farmer
// draws it first, then sees the price and pays (at the end of the designer).
//   - at the sign-up ("بريميوم" chosen): right after the pack;
//   - in the app: Premium "★ ابدأ بريميوم" and "بستاني ★" without an
//     orchard yet.
// THE DRAWING ITSELF IS PHASE 3: "★ ابدأ الرسم" says "قريبًا" for now.
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
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/soon_message.dart';
import '../../shared/widgets/text_link.dart';
import '../onboarding/welcome_screen.dart';
import '../premium/pack_texts.dart';

class DesignerStartScreen extends StatefulWidget {
  const DesignerStartScreen({super.key, this.signUp = false});

  /// true = during the sign-up (no tab bar: the app is not open yet).
  final bool signUp;

  @override
  State<DesignerStartScreen> createState() => _DesignerStartScreenState();
}

class _DesignerStartScreenState extends State<DesignerStartScreen> {
  // The price per zone ("…" while it is read; nothing if it fails).
  late final Future<PackPrice> _price = Future.sync(
    () => paymentService.loadPrice(),
  );
  bool _busy = false;

  /// Sign-up: the free plan for now (Premium can be started later).
  Future<void> _continueFree() async {
    setState(() => _busy = true);
    try {
      updateUser(await authService.choosePlan(Plan.free));
    } catch (_) {
      // Not saved (no internet): the next login shows this screen again.
    }
    if (mounted) replaceAllWith(context, const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [
      (AppIcon.map, l10n.designerStepOutline),
      (AppIcon.tree, l10n.designerStepZones),
      (AppIcon.card, l10n.designerStepPay),
    ];
    final children = [
      ScreenTitle(title: l10n.designerTitle, subtitle: l10n.designerSubtitle),
      CssBox(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        shadows: AppShadows.card,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (icon, text)) in steps.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                children: [
                  IconBlob(icon: icon, size: 54, iconSize: 28),
                  const SizedBox(width: 14),
                  Text(
                    '${i + 1}',
                    style: AppTextStyles.of(
                      22,
                      FontWeight.w800,
                    ).copyWith(color: AppColors.midGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTextStyles.of(19, FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      // The price per zone, from the database.
      FutureBuilder(
        future: _price,
        builder: (context, snapshot) {
          final price = snapshot.data;
          if (snapshot.hasError) return const SizedBox.shrink();
          return Column(
            children: [
              Text(
                price == null ? '…' : pricePerZoneText(l10n, price),
                textAlign: TextAlign.center,
                style: AppTextStyles.of(22, FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.packZoneNote,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(16),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      ActionButton(
        label: '★ ${l10n.startDrawing}',
        // The designer is the next part of the app (phase 3).
        onPressed: _busy ? null : () => showSoon(context),
      ),
      if (widget.signUp) ...[
        const SizedBox(height: 12),
        ActionButton(
          label: l10n.continueFree,
          secondary: true,
          onPressed: _busy ? null : _continueFree,
        ),
      ] else
        TextLink(
          label: l10n.notNow,
          onTap: () => Navigator.of(context).maybePop(),
        ),
    ];
    if (!widget.signUp) return ShellPage(children: children);
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
