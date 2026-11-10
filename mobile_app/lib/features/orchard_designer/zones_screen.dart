// Step 2 of the designer: the zones (one sensor each). The farmer chooses:
//   (a) "أعطي عدد المناطق والأشجار": how many zones, the trees of each →
//       the app cuts straight strips, their areas proportional to the trees;
//   (b) "أرسم خطوط التقسيم بنفسي": he drags lines across the orchard; each
//       line cuts the zones it goes over ("تراجع", "امسح").
// "التالي" saves the draft and opens the details of each zone.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';
import '../../data/orchard_design.dart';
import '../../data/orchard_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/text_link.dart';
import '../onboarding/auth_messages.dart';
import 'design_session.dart';
import 'designer_widgets.dart';
import 'geometry.dart';
import 'orchard_canvas.dart';
import 'zone_details_screen.dart';

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key, required this.session});

  final DesignSession session;

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  late final DesignSession _session = widget.session;
  late List<OrchardPoint> _outline = _session.design.outline;
  late ZoneMethod? _method = _session.design.zones.isEmpty
      ? null
      : _session.design.zoneMethod;
  late List<DesignZone> _zones = _session.design.zones;
  late List<(OrchardPoint, OrchardPoint)> _cuts = _session.design.cuts;
  final List<TextEditingController> _trees = [];
  (OrchardPoint, OrchardPoint)? _cutLine;
  bool _missed = false;
  bool _tooMany = false;
  bool _saving = false;
  AuthFailure? _saveError;

  @override
  void initState() {
    super.initState();
    if (_method == ZoneMethod.auto) {
      _setTreeBoxes([for (final z in _zones) z.treeCount ?? 1]);
    }
  }

  @override
  void dispose() {
    for (final c in _trees) {
      c.dispose();
    }
    super.dispose();
  }

  /// The zone [i] with its new boundary, keeping its details (name, type,
  /// colour) from the draft.
  DesignZone _zoneAt(int i, Polygon boundary, int trees) {
    final old = _session.design.zones;
    final prev = i < old.length ? old[i] : null;
    return DesignZone(
      letter: zoneLetter(i),
      boundary: rounded(boundary),
      color: prev?.color ?? zoneColors[i % zoneColors.length],
      name: prev?.name ?? '',
      type: prev?.type,
      treeCount: trees,
    );
  }

  // ----- (a) automatic -----

  void _setTreeBoxes(List<int> trees) {
    for (final c in _trees) {
      c.dispose();
    }
    _trees
      ..clear()
      ..addAll([for (final t in trees) TextEditingController(text: '$t')]);
  }

  List<int?> get _typedTrees => [for (final c in _trees) parseWhole(c.text)];

  void _split() {
    final trees = [for (final t in _typedTrees) math.max(1, t ?? 1)];
    final parts = splitByTrees(_outline, trees);
    _zones = [for (final (i, p) in parts.indexed) _zoneAt(i, p, trees[i])];
  }

  void _chooseAuto() {
    final ha = hectares(_outline);
    final count = (ha / 2).ceil().clamp(2, maxZones);
    final share = shareTrees(_session.totalTrees, List.filled(count, 1.0));
    setState(() {
      _method = ZoneMethod.auto;
      _setTreeBoxes(share);
      _split();
    });
  }

  void _setCount(int count) {
    if (count < 1 || count > maxZones) return;
    final typed = [for (final t in _typedTrees) t ?? 1];
    final average = typed.isEmpty
        ? 1
        : math.max(1, typed.reduce((a, b) => a + b) ~/ typed.length);
    final trees = [
      for (var i = 0; i < count; i++) i < typed.length ? typed[i] : average,
    ];
    setState(() {
      _setTreeBoxes(trees);
      _split();
    });
  }

  // ----- (b) the farmer's lines -----

  void _chooseDraw() => setState(() {
    _method = ZoneMethod.draw;
    _cuts = [];
    _rebuildFromCuts();
  });

  void _rebuildFromCuts() {
    var parts = <Polygon>[_outline];
    for (final (a, b) in _cuts) {
      parts = cutZones(parts, a, b) ?? parts;
    }
    final trees = shareTrees(_session.totalTrees, [
      for (final p in parts) polygonArea(p),
    ]);
    _zones = [for (final (i, p) in parts.indexed) _zoneAt(i, p, trees[i])];
  }

  void _cutStart(OrchardPoint p, CanvasView view) => setState(() {
    _missed = false;
    _tooMany = false;
    _cutLine = (p, p);
  });

  void _cutMove(OrchardPoint p, CanvasView view) {
    final line = _cutLine;
    if (line != null) setState(() => _cutLine = (line.$1, p));
  }

  void _cutEnd() {
    final line = _cutLine;
    setState(() => _cutLine = null);
    if (line == null || distance(line.$1, line.$2) < 0.5) return;
    if (_zones.length >= maxZones) {
      setState(() => _tooMany = true);
      return;
    }
    final parts = cutZones(
      [for (final z in _zones) z.boundary],
      line.$1,
      line.$2,
    );
    if (parts == null) {
      setState(() => _missed = true);
      return;
    }
    setState(() {
      _cuts = [..._cuts, line];
      _rebuildFromCuts();
      _tooMany = _zones.length > maxZones;
    });
  }

  void _undoCut() => setState(() {
    _missed = false;
    _tooMany = false;
    _cuts = _cuts.sublist(0, _cuts.length - 1);
    _rebuildFromCuts();
  });

  void _eraseCuts() => setState(() {
    _missed = false;
    _tooMany = false;
    _cuts = [];
    _rebuildFromCuts();
  });

  // ----- both -----

  /// What stops "التالي" (null = nothing).
  String? _problem(AppLocalizations l10n) {
    if (_method == ZoneMethod.auto) {
      if (_typedTrees.any((t) => t == null || t < 1 || t > 20000)) {
        return l10n.treesAtLeastOne;
      }
      if (_zones.any((z) => polygonArea(z.boundary) < minPolygonArea)) {
        return l10n.zoneTooSmall;
      }
    }
    if (_zones.length > maxZones || _tooMany) {
      return l10n.tooManyZones(maxZones);
    }
    return null;
  }

  Future<void> _next() async {
    final next = _session.design.copyWith(
      step: DesignStep.zones,
      zoneMethod: _method,
      zones: _zones,
      cuts: _method == ZoneMethod.draw ? _cuts : const [],
    );
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _session.save(next);
      if (mounted) {
        await openScreen(context, ZoneDetailsScreen(session: _session));
        // Back from the details: what was saved there (names, trees...).
        if (mounted) setState(() => _zones = _session.design.zones);
      }
    } on AuthError catch (error) {
      if (mounted) setState(() => _saveError = error.failure);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<CanvasZone> get _canvasZones => [
    for (final z in _zones)
      CanvasZone(letter: z.letter, boundary: z.boundary, color: z.color),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    _outline = _session.design.outline;
    final problem = _problem(l10n);
    final saveError = _saveError;
    final method = _method;
    final String hint;
    var isProblem = false;
    if (method == null) {
      hint = l10n.zonesSubtitle;
    } else if (_missed) {
      hint = l10n.cutMissed;
      isProblem = true;
    } else if (problem != null) {
      hint = problem;
      isProblem = true;
    } else {
      hint = method == ZoneMethod.auto ? l10n.methodAutoHint : l10n.hintCut;
    }

    final Widget body;
    if (method == null) {
      body = ListView(
        children: [
          CanvasCard(
            height: 200,
            child: OrchardCanvas(
              frame: frameAround(_outline),
              semanticLabel: l10n.a11yOrchardDrawing,
              outline: _outline,
            ),
          ),
          const SizedBox(height: 14),
          ChoiceCard(
            icon: AppIcon.tree,
            title: l10n.methodAuto,
            subtitle: l10n.methodAutoHint,
            onTap: _chooseAuto,
          ),
          const SizedBox(height: 12),
          ChoiceCard(
            icon: AppIcon.scissors,
            title: l10n.methodDraw,
            subtitle: l10n.methodDrawHint,
            onTap: _chooseDraw,
          ),
        ],
      );
    } else if (method == ZoneMethod.auto) {
      body = ListView(
        children: [
          CanvasCard(
            height: 210,
            child: OrchardCanvas(
              frame: frameAround(_outline),
              semanticLabel: l10n.a11yOrchardDrawing,
              outline: _outline,
              zones: _canvasZones,
            ),
          ),
          const SizedBox(height: 12),
          _CountRow(count: _trees.length, onChange: _setCount),
          const SizedBox(height: 8),
          for (final (i, zone) in _zones.indexed)
            if (i < _trees.length)
              _TreesRow(
                zone: zone,
                controller: _trees[i],
                error: (_typedTrees[i] ?? 0) < 1,
                onChanged: () => setState(_split),
              ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ToolButton(
                icon: AppIcon.undo,
                label: l10n.toolUndo,
                onTap: _cuts.isEmpty ? null : _undoCut,
              ),
              const SizedBox(width: 8),
              ToolButton(
                icon: AppIcon.erase,
                label: l10n.toolErase,
                onTap: _cuts.isEmpty ? null : _eraseCuts,
              ),
              const Spacer(),
              Text(
                l10n.zonesCount(_zones.length),
                style: AppTextStyles.of(19, FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CanvasCard(
              child: OrchardCanvas(
                frame: frameAround(_outline),
                semanticLabel: l10n.a11yOrchardDrawing,
                outline: _outline,
                zones: _canvasZones,
                cutLine: _cutLine,
                onDragStart: _cutStart,
                onDrag: _cutMove,
                onDragEnd: _cutEnd,
              ),
            ),
          ),
        ],
      );
    }

    return DesignerPage(
      step: 2,
      title: l10n.zonesTitle,
      hint: HintLine(hint, problem: isProblem),
      body: body,
      bottom: [
        if (saveError != null) AuthNote.failure(saveError),
        if (method != null) ...[
          ActionButton(
            label: _saving ? l10n.saving : '★ ${l10n.next}',
            onPressed: problem == null && !_saving ? _next : null,
          ),
          TextLink(
            label: l10n.changeMethod,
            onTap: () => setState(() {
              _method = null;
              _missed = false;
              _tooMany = false;
            }),
          ),
        ],
      ],
    );
  }
}

/// "عدد المناطق  [−] 3 [+]".
class _CountRow extends StatelessWidget {
  const _CountRow({required this.count, required this.onChange});

  final int count;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget round(AppIcon icon, String label, int to, bool enabled) => Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? () => onChange(to) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: CssBox(
            width: 52,
            height: 52,
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            shadows: AppShadows.langPill,
            alignment: Alignment.center,
            child: LoozIcon(icon, size: 26),
          ),
        ),
      ),
    );
    return CssBox(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      shadows: AppShadows.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.zonesHowMany,
              style: AppTextStyles.of(18, FontWeight.w800),
            ),
          ),
          round(AppIcon.minus, l10n.fewer, count - 1, count > 1),
          SizedBox(
            width: 52,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: AppTextStyles.of(26, FontWeight.w800),
            ),
          ),
          round(AppIcon.plus, l10n.more, count + 1, count < maxZones),
        ],
      ),
    );
  }
}

/// A zone and the box of its trees.
class _TreesRow extends StatelessWidget {
  const _TreesRow({
    required this.zone,
    required this.controller,
    required this.error,
    required this.onChanged,
  });

  final DesignZone zone;
  final TextEditingController controller;
  final bool error;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          ZoneDot(zone: zone),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              zoneTitle(l10n, zone),
              style: AppTextStyles.of(18, FontWeight.w700),
            ),
          ),
          const LoozIcon(AppIcon.tree, size: 24),
          const SizedBox(width: 6),
          NumberBox(
            controller: controller,
            width: 104,
            error: error,
            semanticLabel: '${zoneTitle(l10n, zone)} · ${l10n.treesLabel}',
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
