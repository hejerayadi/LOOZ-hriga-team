// Tab 3 — My orchard ("بستاني ★"):
//  - Premium: the farmer's REAL orchard (Supabase) in 3D, in a card under
//    the title; no orchard built yet: "ارسم بستانك" (the designer);
//  - free plan: the design's "locked" screen (what Premium gives).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';
import '../../data/orchard_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/orchard_scene.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/symbol_text.dart';
import '../../shared/widgets/text_link.dart';
import '../onboarding/auth_messages.dart';
import '../orchard_designer/designer_start_screen.dart';
import '../premium/premium_screen.dart';
import '../../data/ml_service.dart';
import 'orchard_3d_data.dart';
import 'orchard_3d_view.dart';
import 'orchard_live_store.dart';
import 'zone_panel.dart';

/// true while a panel of the 3D page covers the bottom of the screen:
/// the assistant bar is hidden then (see MainShell in app.dart).
final ValueNotifier<bool> orchardPanelOpen = ValueNotifier(false);

class OrchardTab extends StatelessWidget {
  const OrchardTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds as soon as the plan changes.
    return ValueListenableBuilder<Plan>(
      valueListenable: currentPlan,
      builder: (context, plan, _) => canUse(Feature.orchard3d)
          ? const _MyOrchard()
          : const _LockedOrchard(),
    );
  }
}

/// The title "بستاني ★" (with a gold star).
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return ScreenTitle(
      title: '${context.l10n.myOrchard} ★',
      symbolColor: AppColors.midGreen,
    );
  }
}

/// Premium: reads the orchard, then shows it (or what is missing).
class _MyOrchard extends StatefulWidget {
  const _MyOrchard();

  @override
  State<_MyOrchard> createState() => _MyOrchardState();
}

class _MyOrchardState extends State<_MyOrchard> {
  late Future<MyOrchard?> _orchard = _load();

  // (Future.sync: even an error at once arrives in the FutureBuilder.)
  Future<MyOrchard?> _load() => Future.sync(orchardService.loadMyOrchard);

  // (A block: setState must not get the Future back.)
  void _retry() => setState(() {
    _orchard = _load();
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _orchard,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _OrchardCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final error = snapshot.error;
        if (error != null) {
          return ShellContent(
            children: [
              const _Title(),
              AuthNote.failure(
                error is AuthError ? error.failure : AuthFailure.unknown,
              ),
              const SizedBox(height: 20),
              ActionButton(label: context.l10n.tryAgain, onPressed: _retry),
            ],
          );
        }
        final orchard = snapshot.data;
        if (orchard == null || !orchard.complete) {
          return const _DrawYourOrchard();
        }
        return _Orchard3d(orchard: orchard);
      },
    );
  }
}

/// The title and a big white card that fills the tab (above the bars).
class _OrchardCard extends StatelessWidget {
  const _OrchardCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.paddingOf(context);
    final side = AppSpacing.pageSide(context);
    // The card ends 12 px above the assistant bar.
    const bottom =
        AppSizes.assistantBarBottom + AppSizes.assistantBarHeight + 12;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        side,
        system.top + AppSpacing.pageTop,
        side,
        system.bottom + bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title(),
          Expanded(
            child: CssBox(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(34),
              shadows: AppShadows.card,
              clip: true,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// The 3D orchard (assets/orchard_3d/), in the big white card.
class _Orchard3d extends StatefulWidget {
  const _Orchard3d({required this.orchard});

  final MyOrchard orchard;

  @override
  State<_Orchard3d> createState() => _Orchard3dState();
}

class _Orchard3dState extends State<_Orchard3d> {
  // The orchard sent to the 3D page. (Made once: a language change only
  // switches the page's texts.)
  late final String _orchardJson = orchard3dJson(
    widget.orchard,
    language: Localizations.localeOf(context).languageCode,
  );

  // The live states sent to the page, made again only when they change.
  OrchardLive? _liveFor;
  String? _liveJson;

  /// The zone highlighted in the 3D (its panel is open).
  String? _focused;

  @override
  void initState() {
    super.initState();
    focusZone.addListener(_onFocus);
    refreshOrchardLive();
    // A tap on an alert may have asked for a zone before this tab was built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFocus());
  }

  @override
  void dispose() {
    focusZone.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    final id = focusZone.value;
    if (id == null || !mounted) return;
    focusZone.value = null;
    _openZone(id);
  }

  /// The panel of a zone (from the 3D, an alert or a notification).
  void _openZone(String zoneId) {
    final zone = widget.orchard.zones.where((z) => z.id == zoneId).firstOrNull;
    if (zone == null) return;
    final node = widget.orchard.nodes.where((n) => n.zoneId == zoneId).firstOrNull;
    setState(() => _focused = zoneId);
    orchardPanelOpen.value = true;
    showZonePanel(context, zone: zone, node: node).whenComplete(() {
      orchardPanelOpen.value = false;
      if (mounted) setState(() => _focused = null);
    });
  }

  /// Messages sent by the 3D page (assets/orchard_3d/index.html).
  void _onMessage(String message) {
    if (message.startsWith('looz:zone:')) {
      _openZone(message.substring('looz:zone:'.length));
      return;
    }
    switch (message) {
      case 'looz:upgrade': // "ابدأ بريميوم" tapped in the zone panel
        openScreen(context, const PremiumScreen());
      case 'looz:buttons:hide':
        orchardPanelOpen.value = true;
      case 'looz:buttons:show':
        orchardPanelOpen.value = false;
    }
  }

  String? _live(OrchardLive? live) {
    if (live == null) return null;
    if (!identical(live, _liveFor)) {
      _liveFor = live;
      _liveJson = orchardLiveJson(widget.orchard, live);
    }
    return _liveJson;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OrchardLiveState>(
      valueListenable: orchardLive,
      builder: (context, state, _) => _OrchardCard(
        child: Orchard3dView(
          data: _orchardJson,
          language: Localizations.localeOf(context).languageCode,
          onMessage: _onMessage,
          live: _live(state.live),
          focus: _focused,
        ),
      ),
    );
  }
}

/// Premium, but no orchard built yet: draw it first (the designer).
class _DrawYourOrchard extends StatelessWidget {
  const _DrawYourOrchard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ShellContent(
      children: [
        const _Title(),
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(34),
          shadows: AppShadows.card,
          clip: true,
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OrchardScene(radius: 0),
              const SizedBox(height: 10),
              Text(
                l10n.designerTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(23, FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.packZoneNote,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ActionButton(
          label: '★ ${l10n.startDrawing}',
          onPressed: () => openScreen(context, const DesignerStartScreen()),
        ),
      ],
    );
  }
}

/// The design's "locked" screen: the drawing with a gold star, what Premium
/// gives, and the button to start it.
class _LockedOrchard extends StatelessWidget {
  const _LockedOrchard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final benefits = [
      (AppIcon.map, l10n.benefitTreeMap),
      (AppIcon.drop, l10n.benefitSmartWatering),
      (AppIcon.bell, l10n.benefitEarlyAlert),
    ];
    return ShellContent(
      children: [
        const _Title(),
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(34),
          shadows: AppShadows.card,
          clip: true,
          padding: const EdgeInsets.only(bottom: 18),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OrchardScene(radius: 0),
                  Text(
                    l10n.orchardInPocket,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.of(23, FontWeight.w700),
                  ),
                ],
              ),
              // Like in the design, the star covers the middle of the text.
              Positioned(
                top: 135,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.midGreen,
                      shape: BoxShape.circle,
                    ),
                    child: SymbolText(
                      '★',
                      style: AppTextStyles.of(28)
                          .copyWith(color: AppColors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, (icon, label)) in benefits.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    IconBlob(icon: icon),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.of(14, FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        ActionButton(
          label: '★ ${l10n.startPremium}',
          onPressed: () => openScreen(context, const PremiumScreen()),
        ),
        TextLink(
          label: l10n.notNow,
          onTap: () => goToTab(context, AppTab.home),
        ),
      ],
    );
  }
}
