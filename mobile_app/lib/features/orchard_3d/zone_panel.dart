// The panel of a zone (a tap on a zone or its box in the 3D, or on an alert of
// "بستاني"): its state (colour, icon, short words), how sure, when it was
// updated, the main reasons as simple bars, the explanation and ONE action,
// tonight's frost line and the latest readings. It follows the live state:
// a new reading or prediction changes it while it is open.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../data/ml_service.dart';
import '../../data/orchard_service.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import 'orchard_3d_data.dart' show zoneName;
import 'orchard_live_store.dart';
import 'zone_live_texts.dart';

/// Opens the panel of [zone] (its box: [node]).
Future<void> showZonePanel(
  BuildContext context, {
  required OrchardZone zone,
  SensorNode? node,
}) {
  // Its notifications are seen now.
  final live = orchardLive.value.live;
  if (node != null && live != null) {
    markMlRead([
      for (final n in live.notifications)
        if (n.nodeId == node.id) n.id,
    ]);
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ZonePanel(zone: zone, node: node),
  );
}

class ZonePanel extends StatelessWidget {
  const ZonePanel({super.key, required this.zone, this.node, this.now});

  final OrchardZone zone;
  final SensorNode? node;

  /// For the tests ("منذ 5 دقائق").
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OrchardLiveState>(
      valueListenable: orchardLive,
      builder: (context, state, _) {
        final live = state.live ?? const OrchardLive();
        final z = live.zone(node?.id, installed: node?.installed ?? false);
        return _Sheet(zone: zone, live: z, now: now);
      },
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.zone, required this.live, this.now});

  final OrchardZone zone;
  final ZoneLive live;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final name = zoneName(zone, language);
    final state = live.state;
    final color = zoneStateColor(state);
    final main = live.main;
    final updated = live.node?.receivedAt ?? main?.predictedAt;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: CssBox(
        color: AppColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(name, style: AppTextStyles.of(24, FontWeight.w800)),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.a11yClose,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, color: AppColors.green, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _StateRow(state: state, color: color, likely: main?.likely),
                if (updated != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.mlUpdated(timeAgo(l10n, updated, now)),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(height: 16),
                ..._body(context, name, language),
                if (live.node != null && state != ZoneState.waiting) ...[
                  const SizedBox(height: 18),
                  _Readings(node: live.node!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, String name, String language) {
    final l10n = context.l10n;
    final main = live.main;
    String? note = switch (live.state) {
      ZoneState.notEnoughData => l10n.mlNotEnoughDataText,
      ZoneState.sensorProblem => l10n.mlSensorProblemText,
      ZoneState.offline => l10n.mlOfflineText,
      ZoneState.waiting => l10n.mlWaitingText,
      _ => null,
    };
    if (note != null || main == null) {
      return [_Note(text: note ?? l10n.mlNotEnoughDataText)];
    }
    final frost = live.frost;
    return [
      _Card(
        child: Text(explanationOf(l10n, main, name, language), style: AppTextStyles.body),
      ),
      const SizedBox(height: 12),
      _Action(text: actionOf(l10n, main, language)),
      if (main.factors.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(l10n.mlWhy, style: AppTextStyles.sectionTitle),
        const SizedBox(height: 8),
        for (final f in main.factors) _FactorBar(text: factorText(l10n, f), share: f.share),
      ],
      // The other model in one line: tonight's frost (or the trees).
      if (frost != null && frost.ok && main != frost) ...[
        const SizedBox(height: 14),
        _Line(
          label: l10n.mlTonight,
          text: frost.state == 'frost_risk' ? l10n.mlStateFrostRisk : l10n.mlStateNoFrost,
          icon: AppIcon.snow,
        ),
      ],
      if (live.stress != null && live.stress!.ok && main != live.stress) ...[
        const SizedBox(height: 10),
        _Line(
          label: l10n.mlTrees,
          text: zoneStateName(l10n, zoneStateOf(live.stress!.state) ?? ZoneState.ok),
          icon: AppIcon.tree,
        ),
      ],
    ];
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({required this.state, required this.color, this.likely});

  final ZoneState state;
  final Color color;
  final bool? likely;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sure = likely;
    final hasCertainty = sure != null && !{
      ZoneState.sensorProblem,
      ZoneState.notEnoughData,
      ZoneState.offline,
      ZoneState.waiting,
    }.contains(state);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoozIcon(zoneStateIcon(state), size: 22, color: AppColors.white),
              const SizedBox(width: 8),
              Text(
                zoneStateName(l10n, state),
                style: AppTextStyles.of(18, FontWeight.w800).copyWith(color: AppColors.white),
              ),
            ],
          ),
        ),
        if (hasCertainty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: color, width: 2),
            ),
            child: Text(
              sure ? l10n.verdictLikely : l10n.verdictUnsure,
              style: AppTextStyles.of(16, FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CssBox(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppRadius.md),
    shadows: AppShadows.card,
    padding: const EdgeInsets.all(16),
    child: child,
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => CssBox(
    color: AppColors.lightGreen,
    borderRadius: BorderRadius.circular(AppRadius.md),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.whatToDo, style: AppTextStyles.of(18, FontWeight.w800)),
        const SizedBox(height: 4),
        Text(text, style: AppTextStyles.of(18, FontWeight.w700)),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => _Card(child: Text(text, style: AppTextStyles.body));
}

/// A reason: its words and a bar (its part of the push).
class _FactorBar extends StatelessWidget {
  const _FactorBar({required this.text, required this.share});

  final String text;
  final double share;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: AppTextStyles.of(17, FontWeight.w700)),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, c) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                height: 12,
                width: c.maxWidth * share.clamp(0.08, 1.0),
                decoration: BoxDecoration(
                  color: AppColors.midGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.text, required this.icon});

  final String label;
  final String text;
  final AppIcon icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      LoozIcon(icon, size: 24),
      const SizedBox(width: 8),
      Text('$label: ', style: AppTextStyles.of(17, FontWeight.w800)),
      Expanded(child: Text(text, style: AppTextStyles.of(17, FontWeight.w600))),
    ],
  );
}

/// The latest readings of the box, in big numbers.
class _Readings extends StatelessWidget {
  const _Readings({required this.node});

  final NodeLive node;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String n(double? v, String unit) => v == null ? '—' : '${v.round()}$unit';
    final items = [
      (AppIcon.drop, l10n.mlSoilWater, n(node.soilMoisture, ' %')),
      (AppIcon.thermo, l10n.mlAirTemp, n(node.airTemp, '°')),
      (AppIcon.leaf, l10n.mlSoilTemp, n(node.soilTemp, '°')),
      (AppIcon.rain, l10n.mlHumidity, n(node.humidity, ' %')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.mlReadings, style: AppTextStyles.sectionTitle),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [
            for (final (icon, label, value) in items)
              CssBox(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    LoozIcon(icon, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(value, style: AppTextStyles.of(22, FontWeight.w800)),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
