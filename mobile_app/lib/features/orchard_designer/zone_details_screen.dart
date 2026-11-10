// Step 2 (end) of the designer: each zone, its trees, its type, its name
// and its colour. A tap on a zone opens a sheet to change them. With the
// automatic zones, new numbers of trees cut the orchard again.
// "التالي" saves the draft (step "review") and opens the review.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validators.dart';
import '../../data/auth_service.dart';
import '../../data/orchard_design.dart';
import '../../data/orchard_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import '../onboarding/auth_messages.dart';
import '../orchard_3d/orchard_3d_data.dart' show zoneTypeName;
import 'design_session.dart';
import 'designer_widgets.dart';
import 'geometry.dart';
import 'orchard_canvas.dart';
import 'review_screen.dart';

/// A zone's own name: at most 30 letters (like the database).
const zoneNameMax = 30;

/// What is wrong with a zone's name (null = fine; empty is fine).
String? zoneNameProblem(AppLocalizations l10n, String name) {
  final clean = name.trim();
  if (clean.isEmpty) return null;
  if (clean.runes.length > zoneNameMax) return l10n.nameTooLong('$zoneNameMax');
  if (checkText(clean) == TextProblem.badCharacters) {
    return l10n.textBadCharacters;
  }
  return null;
}

class ZoneDetailsScreen extends StatefulWidget {
  const ZoneDetailsScreen({super.key, required this.session});

  final DesignSession session;

  @override
  State<ZoneDetailsScreen> createState() => _ZoneDetailsScreenState();
}

class _ZoneDetailsScreenState extends State<ZoneDetailsScreen> {
  late final DesignSession _session = widget.session;
  late List<DesignZone> _zones = _session.design.zones;
  bool _saving = false;
  AuthFailure? _saveError;

  Future<void> _edit(int index) async {
    final edited = await showModalBottomSheet<DesignZone>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _ZoneSheet(zone: _zones[index]),
    );
    if (edited == null || !mounted) return;
    setState(() {
      final zones = [..._zones]..[index] = edited;
      final treesChanged = edited.treeCount != _zones[index].treeCount;
      if (_session.design.zoneMethod == ZoneMethod.auto && treesChanged) {
        // Automatic zones: the new trees cut the orchard again.
        final parts = splitByTrees(_session.design.outline, [
          for (final z in zones) z.treeCount ?? 1,
        ]);
        _zones = [
          for (final (i, z) in zones.indexed)
            z.copyWith(boundary: rounded(parts[i])),
        ];
      } else {
        _zones = zones;
      }
    });
  }

  Future<void> _next() async {
    final next = _session.design.copyWith(
      step: DesignStep.review,
      zones: _zones,
    );
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _session.save(next);
      if (mounted) await openScreen(context, ReviewScreen(session: _session));
    } on AuthError catch (error) {
      if (mounted) setState(() => _saveError = error.failure);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outline = _session.design.outline;
    final tooSmall = _zones.any(
      (z) => polygonArea(z.boundary) < minPolygonArea,
    );
    final saveError = _saveError;
    return DesignerPage(
      step: 2,
      title: l10n.zoneDetailsTitle,
      hint: HintLine(
        tooSmall ? l10n.zoneTooSmall : l10n.zoneDetailsSubtitle,
        problem: tooSmall,
      ),
      body: ListView(
        children: [
          CanvasCard(
            height: 190,
            child: OrchardCanvas(
              frame: frameAround(outline),
              semanticLabel: l10n.a11yOrchardDrawing,
              outline: outline,
              zones: [
                for (final z in _zones)
                  CanvasZone(
                    letter: z.letter,
                    boundary: z.boundary,
                    color: z.color,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (final (i, zone) in _zones.indexed)
            _ZoneCard(zone: zone, onTap: () => _edit(i)),
        ],
      ),
      bottom: [
        if (saveError != null) AuthNote.failure(saveError),
        ActionButton(
          label: _saving ? l10n.saving : '★ ${l10n.next}',
          onPressed: _saving || tooSmall ? null : _next,
        ),
      ],
    );
  }
}

/// One zone: its colour and letter, its name, its trees and type.
class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.onTap});

  final DesignZone zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = zone.type;
    final details = [
      l10n.treeCount('${zone.treeCount ?? 0}'),
      if (type != null) zoneTypeName(l10n, type),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: CssBox(
            minHeight: 76,
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            shadows: AppShadows.card,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                ZoneDot(zone: zone, size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        zoneTitle(l10n, zone),
                        style: AppTextStyles.of(19, FontWeight.w800),
                      ),
                      Text(details, style: AppTextStyles.of(15)),
                    ],
                  ),
                ),
                const LoozIcon(AppIcon.pen, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet of one zone: name, type, trees, colour; "تمّ" gives it back.
class _ZoneSheet extends StatefulWidget {
  const _ZoneSheet({required this.zone});

  final DesignZone zone;

  @override
  State<_ZoneSheet> createState() => _ZoneSheetState();
}

class _ZoneSheetState extends State<_ZoneSheet> {
  late final _name = TextEditingController(text: widget.zone.name);
  late final _trees = TextEditingController(
    text: '${widget.zone.treeCount ?? 1}',
  );
  late ZoneType? _type = widget.zone.type;
  late String _color = widget.zone.color;
  bool _tried = false;

  @override
  void dispose() {
    _name.dispose();
    _trees.dispose();
    super.dispose();
  }

  int? get _treeValue {
    final v = parseWhole(_trees.text);
    return v != null && v >= 1 && v <= 20000 ? v : null;
  }

  void _done() {
    final l10n = context.l10n;
    setState(() => _tried = true);
    if (_treeValue == null || zoneNameProblem(l10n, _name.text) != null) {
      return;
    }
    Navigator.of(context).pop(
      widget.zone.copyWith(
        name: _name.text.trim(),
        type: _type,
        clearType: _type == null,
        color: _color,
        treeCount: _treeValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nameProblem = _tried ? zoneNameProblem(l10n, _name.text) : null;
    final treesWrong = _tried && _treeValue == null;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(text, style: AppTextStyles.of(17, FontWeight.w800)),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ZoneDot(zone: widget.zone.copyWith(color: _color), size: 44),
                const SizedBox(width: 12),
                Text(
                  l10n.zoneName(widget.zone.letter),
                  style: AppTextStyles.of(22, FontWeight.w800),
                ),
              ],
            ),
            // The trees (needed).
            label(l10n.treesLabel),
            Row(
              children: [
                const LoozIcon(AppIcon.tree, size: 28),
                const SizedBox(width: 10),
                NumberBox(
                  controller: _trees,
                  width: 130,
                  error: treesWrong,
                  semanticLabel: l10n.treesLabel,
                  onChanged: (_) => _tried ? setState(() {}) : null,
                ),
              ],
            ),
            if (treesWrong) ...[
              const SizedBox(height: 6),
              HintLine(l10n.treesAtLeastOne, problem: true),
            ],
            // The type (a tap again = none).
            label(l10n.zoneTypeLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in ZoneType.values)
                  _Chip(
                    label: zoneTypeName(l10n, type),
                    selected: _type == type,
                    onTap: () =>
                        setState(() => _type = _type == type ? null : type),
                  ),
              ],
            ),
            // The name (optional).
            label(l10n.zoneNameOptional),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: nameProblem != null
                      ? AppColors.danger
                      : AppColors.mint,
                  width: 2,
                ),
              ),
              child: TextField(
                controller: _name,
                maxLength: zoneNameMax,
                style: AppTextStyles.of(19, FontWeight.w700),
                cursorColor: AppColors.green,
                onChanged: (_) => _tried ? setState(() {}) : null,
                decoration: InputDecoration(
                  isCollapsed: true,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: l10n.zoneName(widget.zone.letter),
                ),
              ),
            ),
            if (nameProblem != null) ...[
              const SizedBox(height: 6),
              HintLine(nameProblem, problem: true),
            ],
            // The colour.
            label(l10n.zoneColorLabel),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in zoneColors)
                  Semantics(
                    button: true,
                    selected: c == _color,
                    label:
                        '${l10n.zoneColorLabel} ${zoneColors.indexOf(c) + 1}',
                    child: GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colorOf(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == _color
                                ? AppColors.green
                                : AppColors.white,
                            width: 4,
                          ),
                        ),
                        child: c == _color
                            ? const Center(
                                child: LoozIcon(
                                  AppIcon.check,
                                  size: 22,
                                  color: AppColors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ActionButton(label: l10n.done, onPressed: _done),
          ],
        ),
      ),
    );
  }
}

/// A choice in a pill (the type of a zone).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          minHeight: 48,
          color: selected ? AppColors.green : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          shadows: AppShadows.langPill,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: AppTextStyles.of(
              16,
              FontWeight.w700,
            ).copyWith(color: selected ? AppColors.white : AppColors.green),
          ),
        ),
      ),
    );
  }
}
