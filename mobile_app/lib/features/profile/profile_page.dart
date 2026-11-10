// Tab 5 — Profile ("حسابي"): the farmer (name and phone number), the plan,
// become an expert, the states of the app, and log out.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validators.dart';
import '../../data/payment_service.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/symbol_text.dart';
import '../onboarding/start_screen.dart';
import '../premium/pack_texts.dart';
import '../premium/premium_screen.dart';
import '../states/states_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logOut(BuildContext context) async {
    await logOut();
    if (context.mounted) replaceAllWith(context, const StartScreen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const avatar = Size.square(86);
    return ShellContent(
      children: [
        const LoozHeader(),
        const SizedBox(height: 42),
        // The farmer, from the database: the first letter of the first
        // name, the full name, and the phone number.
        ValueListenableBuilder(
          valueListenable: currentUser,
          builder: (context, user, _) => Row(
            children: [
              Container(
                width: avatar.width,
                height: avatar.height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.leaf,
                  borderRadius: blobRadius(avatar, BlobShapes.avatar),
                ),
                child: Text(
                  user?.initial ?? '',
                  style: AppTextStyles.of(34, FontWeight.w800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? '',
                      style: AppTextStyles.headline.copyWith(fontSize: 26),
                    ),
                    // Numbers are always written left to right.
                    Text(
                      formatPhone(user?.phone ?? ''),
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.of(16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        _ProfileRow(
          icon: AppIcon.tree,
          label: l10n.myPlan,
          subtitle: const _MyPack(),
          end: SymbolText(
            '★',
            style: AppTextStyles.of(19).copyWith(color: AppColors.midGreen),
          ),
          onTap: () => openScreen(context, const PremiumScreen()),
        ),
        _ProfileRow(
          icon: AppIcon.people,
          label: l10n.becomeExpert,
          // DEMO: there is no "become an expert" screen in the design yet.
          onTap: null,
        ),
        _ProfileRow(
          icon: AppIcon.wifi,
          label: l10n.appStates,
          onTap: () => openScreen(context, const StatesScreen()),
        ),
        // Forgets the session on this phone: back to the first screen.
        _ProfileRow(
          icon: AppIcon.logout,
          label: l10n.logOut,
          end: const SizedBox.shrink(),
          onTap: () => _logOut(context),
        ),
        // Only for developers (debug builds): change the fake plan.
        if (kDebugMode) const _DevPlanSwitch(),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.end,
    this.subtitle,
  });

  final AppIcon icon;
  final String label;
  final VoidCallback? onTap;

  /// A small line under the label (e.g. the pack and its end).
  final Widget? subtitle;

  /// At the end of the row (default: an arrow).
  final Widget? end;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: CssBox(
            // At least 86 (the design); taller when the pack line takes 2
            // lines on a narrow phone.
            minHeight: 86,
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            shadows: AppShadows.card,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconBlob(icon: icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.cardTitle),
                      ?subtitle,
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                end ?? const LoozIcon(AppIcon.arrow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Debug builds only: the 2 plans, to see the locked screens.
class _DevPlanSwitch extends StatelessWidget {
  const _DevPlanSwitch();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final names = {Plan.free: l10n.free, Plan.paid: l10n.planPaid};
    return ValueListenableBuilder<Plan>(
      valueListenable: currentPlan,
      builder: (context, plan, _) => CssBox(
        color: AppColors.white70,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.devPlanSwitch,
              style: AppTextStyles.of(15, FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final p in Plan.values)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: p == plan,
                      child: GestureDetector(
                        onTap: () => currentPlan.value = p,
                        child: Container(
                          height: 38,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p == plan
                                ? AppColors.green
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            names[p]!,
                            style: AppTextStyles.langPill.copyWith(
                              color: p == plan
                                  ? AppColors.white
                                  : AppColors.green,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "بريميوم · 4 مناطق · حتى 3/12/2026", or "مجاني": the pack running now.
class _MyPack extends StatefulWidget {
  const _MyPack();

  @override
  State<_MyPack> createState() => _MyPackState();
}

class _MyPackState extends State<_MyPack> {
  late final Future<ActivePack?> _pack = Future.sync(
    () => paymentService.loadActivePack(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder(
      future: _pack,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final pack = snapshot.data;
        final zones = pack?.zones;
        return Text(
          pack == null
              ? planName(l10n, Plan.free)
              : [
                  planName(l10n, Plan.paid),
                  if (zones != null) l10n.zonesCount(zones),
                  l10n.planUntil(dayText(pack.endsAt)),
                ].join(' · '),
          style: AppTextStyles.of(
            14,
            FontWeight.w600,
          ).copyWith(color: AppColors.textMuted),
        );
      },
    );
  }
}
