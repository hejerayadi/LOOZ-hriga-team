// The problems of the farmer's OWN orchard (predictions of migration 019):
//  - the section "بستاني" of the alerts tab: one card per problem (newest
//    and most serious first), "جديد" until seen; a tap opens the zone in 3D;
//  - the in-app notification: a banner at the top of the app, once, when a
//    new problem appears while the app is open (no push: decision of the user).
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/zone_letters.dart';
import '../../data/ml_service.dart';
import '../../shared/widgets/alert_card.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import '../community/community_widgets.dart' show StateCard;
import '../orchard_3d/orchard_live_store.dart';
import '../orchard_3d/zone_live_texts.dart';

/// "المنطقة ب" / "Zone B", or the farmer's own name of the zone.
String zoneLabel(BuildContext context, MlNotification n) => n.zoneName.isNotEmpty
    ? n.zoneName
    : context.l10n.zoneName(zoneLetterOf(context, n.zoneLetter));

ZoneState _stateOf(MlNotification n) => zoneStateOf(n.state) ?? ZoneState.ok;

/// Opens the zone of [n] in the 3D (its panel), and marks it seen.
void openOrchardZone(BuildContext context, MlNotification n) {
  markMlRead([n.id]);
  goToTab(context, AppTab.orchard);
  focusZone.value = n.zoneId;
}

class OrchardAlertCard extends StatelessWidget {
  const OrchardAlertCard({super.key, required this.notification});

  final MlNotification notification;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final n = notification;
    final state = _stateOf(n);
    final p = orchardLive.value.live?.predictions[n.nodeId]?[n.model];
    final language = Localizations.localeOf(context).languageCode;
    return AlertCard(
      level: zoneStateLevel(state),
      barColor: zoneStateColor(state),
      title: l10n.mlZoneOf(zoneLabel(context, n), zoneStateName(l10n, state)),
      text: p != null && p.state == n.state
          ? actionOf(l10n, p, language)
          : templateAction(
              l10n,
              MlPrediction(
                nodeId: n.nodeId,
                model: n.model,
                status: 'ok',
                state: n.state,
                measuredAt: n.createdAt,
              ),
            ),
      icon: zoneStateIcon(state),
      tag: n.unread ? l10n.alertNew : null,
      semanticLabel: zoneStateName(l10n, state),
      onTap: () => openOrchardZone(context, n),
    );
  }
}

/// The section "بستاني" of the alerts tab (paid farmers).
class OrchardAlertsSection extends StatelessWidget {
  const OrchardAlertsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<OrchardLiveState>(
      valueListenable: orchardLive,
      builder: (context, state, _) {
        final live = state.live;
        final open = [...?live?.open]
          ..sort((a, b) {
            if (a.danger != b.danger) return a.danger ? -1 : 1;
            return b.createdAt.compareTo(a.createdAt);
          });
        if (open.isEmpty) {
          final noData = live == null || live.predictions.isEmpty;
          return StateCard(
            icon: noData ? AppIcon.clock : AppIcon.check,
            text: noData ? l10n.mlNoPredictionYet : l10n.mlAllZonesFine,
            color: AppColors.mint,
            height: 150,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, n) in open.indexed) ...[
              if (i > 0) const SizedBox(height: 16),
              OrchardAlertCard(notification: n),
            ],
          ],
        );
      },
    );
  }
}

/// The in-app notification: a banner at the top of the app, 8 seconds.
class MlBannerHost extends StatefulWidget {
  const MlBannerHost({super.key});

  @override
  State<MlBannerHost> createState() => _MlBannerHostState();
}

class _MlBannerHostState extends State<MlBannerHost> {
  MlNotification? _shown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    mlBanner.addListener(_onBanner);
    _onBanner();
  }

  @override
  void dispose() {
    mlBanner.removeListener(_onBanner);
    _timer?.cancel();
    super.dispose();
  }

  void _onBanner() {
    final n = mlBanner.value;
    if (n == null || !mounted) return;
    setState(() => _shown = n);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 8), _hide);
  }

  void _hide() {
    _timer?.cancel();
    if (mounted) setState(() => _shown = null);
    mlBanner.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final n = _shown;
    final top = MediaQuery.paddingOf(context).top + 8;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(animation),
        child: child,
      ),
      child: n == null
          ? const SizedBox.shrink(key: ValueKey('no-banner'))
          : Padding(
              key: ValueKey(n.id),
              padding: EdgeInsets.fromLTRB(16, top, 16, 0),
              child: _Banner(
                notification: n,
                onTap: () {
                  _hide();
                  openOrchardZone(context, n);
                },
                onClose: _hide,
              ),
            ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.notification, required this.onTap, required this.onClose});

  final MlNotification notification;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = _stateOf(notification);
    final color = zoneStateColor(state);
    return Semantics(
      liveRegion: true,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          shadows: AppShadows.button,
          border: BorderDirectional(start: BorderSide(color: color, width: 7)),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: LoozIcon(zoneStateIcon(state), size: 26, color: AppColors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.mlZoneOf(zoneLabel(context, notification), zoneStateName(l10n, state)),
                      style: AppTextStyles.of(18, FontWeight.w800),
                    ),
                    Text(l10n.mlToastOpen, style: AppTextStyles.caption),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.a11yClose,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: AppColors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
