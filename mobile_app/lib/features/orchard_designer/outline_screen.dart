// Step 1 of the designer: the outline of the orchard, on a grid (north at
// the top). Two ways to draw:
//   - "قلم": the finger draws around the orchard; the app straightens the
//     sides and closes the shape;
//   - "نقاط": a tap on each corner; a tap on the first corner closes it.
// Then the corners can be dragged. "تراجع" / "إعادة" / "امسح". The size in
// metres (width and length) is typed in a sheet; the area is shown in
// hectares. Crossing sides are refused with a short message.
// "التالي" saves the draft (orchard_save_design) and opens the zones.
// "من صورة" (sketch_screen.dart): the outline found on the photo of a sketch,
// with the photo faded behind the grid (or, when none was found, the
// corners tapped on the photo). The photo is never saved.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';
import '../../data/orchard_design.dart';
import '../../data/orchard_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import '../onboarding/auth_messages.dart';
import 'design_session.dart';
import 'designer_widgets.dart';
import 'geometry.dart';
import 'orchard_canvas.dart';
import 'outline_editor.dart';
import 'sketch_reader.dart';
import 'zones_screen.dart';

enum DrawTool { pen, corners }

/// A new drawing: the grid shows about the area said at the sign-up (else
/// 200 m across). The photo of a sketch gets the same size.
double designerStartSide() {
  final ha = currentUser.value?.orchardAreaHa;
  if (ha == null || ha <= 0) return 200;
  return (1.6 * math.sqrt(ha * 10000)).clamp(40.0, 3000.0);
}

class OutlineScreen extends StatefulWidget {
  const OutlineScreen({super.key, required this.session, this.sketch});

  final DesignSession session;

  /// The photo of a sketch ("من صورة"), or null (drawing by hand).
  final SketchPhoto? sketch;

  /// How close (screen points) a finger must be to grab a corner.
  static const grabRadius = 26.0;

  /// How much the finger may wobble around a straight side (points).
  static const wobble = 10.0;

  @override
  State<OutlineScreen> createState() => _OutlineScreenState();
}

class _OutlineScreenState extends State<OutlineScreen> {
  late final OutlineEditor _editor = widget.sketch == null
      ? OutlineEditor(widget.session.design.outline)
      : OutlineEditor(widget.sketch!.outline ?? const [], widget.sketch!.place);
  // No outline found on the photo: the corners are tapped on it.
  late DrawTool _tool = widget.sketch != null && !widget.sketch!.found
      ? DrawTool.corners
      : DrawTool.pen;
  late Bounds _frame = widget.sketch != null
      ? frameAround(_cornersOf(widget.sketch!.place), margin: 0.03)
      : _editor.isEmpty
      ? squareFrame(designerStartSide())
      : frameAround(_editor.points);

  static List<OrchardPoint> _cornersOf(Bounds b) => [
    OrchardPoint(b.minX, b.minZ),
    OrchardPoint(b.maxX, b.maxZ),
  ];

  @override
  void dispose() {
    widget.sketch?.image?.dispose();
    super.dispose();
  }

  List<OrchardPoint> _stroke = [];
  int? _moving;
  CanvasView? _view;
  bool _tooSmallStroke = false;
  bool _saving = false;
  AuthFailure? _saveError;

  void _dragStart(OrchardPoint p, CanvasView view) {
    _view = view;
    _tooSmallStroke = false;
    final corner = _editor.cornerAt(p, view.metres(OutlineScreen.grabRadius));
    if (corner != null && (_editor.closed || _tool == DrawTool.corners)) {
      _editor.startMove();
      _moving = corner;
    } else if (_tool == DrawTool.pen && _editor.isEmpty) {
      _stroke = [p];
    }
    setState(() {});
  }

  void _drag(OrchardPoint p, CanvasView view) {
    final moving = _moving;
    if (moving != null) {
      setState(() => _editor.moveCorner(moving, p));
    } else if (_stroke.isNotEmpty) {
      setState(() => _stroke.add(p));
    }
  }

  void _dragEnd() {
    if (_moving != null) {
      setState(() => _moving = null);
      return;
    }
    if (_stroke.isEmpty) return;
    final view = _view;
    final shape = view == null
        ? null
        : cleanUpStroke(_stroke, tolerance: view.metres(OutlineScreen.wobble));
    setState(() {
      _stroke = [];
      if (shape == null || polygonArea(shape) < minOrchardArea) {
        _tooSmallStroke = true;
      } else {
        _editor.setShape(shape);
      }
    });
  }

  void _tap(OrchardPoint p, CanvasView view) {
    if (_tool != DrawTool.corners || _editor.closed) return;
    _tooSmallStroke = false;
    setState(() {
      if (_editor.nearFirst(p, view.metres(OutlineScreen.grabRadius))) {
        _editor.close();
      } else {
        _editor.addCorner(p);
      }
    });
  }

  void _do(VoidCallback change) => setState(() {
    _tooSmallStroke = false;
    _saveError = null;
    change();
  });

  Future<void> _size() async {
    final b = boundsOf(_editor.points);
    final size = await showSizeSheet(context, width: b.width, length: b.length);
    if (size == null || !mounted) return;
    _do(() {
      _editor.scaleTo(size.$1, size.$2);
      _frame = frameAround(_editor.points);
    });
  }

  Future<void> _next() async {
    final session = widget.session;
    final outline = _editor.saved;
    final old = session.design;
    // The same outline: the zones already made stay. A new one: new zones.
    final next = samePoints(old.outline, outline)
        ? old.copyWith(step: old.zones.isEmpty ? DesignStep.zones : old.step)
        : OrchardDesign(step: DesignStep.zones, outline: outline);
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await session.save(next);
      if (mounted) await openScreen(context, ZonesScreen(session: session));
    } on AuthError catch (error) {
      if (mounted) setState(() => _saveError = error.failure);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _hint(AppLocalizations l10n) {
    if (_tooSmallStroke) return l10n.problemTooSmall;
    switch (_editor.problem) {
      case OutlineProblem.crossing:
        return l10n.problemCrossing;
      case OutlineProblem.tooSmall:
        return l10n.problemTooSmall;
      case null:
        // The outline found on the photo, not changed yet.
        if ((widget.sketch?.found ?? false) && !_editor.canUndo) {
          return l10n.sketchFoundHint;
        }
        return l10n.hintMove;
      case OutlineProblem.open:
        break;
    }
    if (_tool == DrawTool.corners || !_editor.isEmpty) {
      return _editor.points.length >= 3 ? l10n.hintClose : l10n.hintCorners;
    }
    return l10n.hintPen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final problem =
        _tooSmallStroke ||
        _editor.problem == OutlineProblem.crossing ||
        _editor.problem == OutlineProblem.tooSmall;
    final closed = _editor.closed && _editor.points.length >= 3;
    final b = closed ? boundsOf(_editor.points) : null;
    final saveError = _saveError;
    return DesignerPage(
      step: 1,
      title: l10n.designerStepOutline,
      hint: HintLine(_hint(l10n), problem: problem),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The tools: draw with the finger, tap corners, undo, redo, erase.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ToolButton(
                icon: AppIcon.pen,
                label: l10n.toolPen,
                selected: _tool == DrawTool.pen,
                onTap: () => _do(() => _tool = DrawTool.pen),
              ),
              ToolButton(
                icon: AppIcon.corners,
                label: l10n.toolCorners,
                selected: _tool == DrawTool.corners,
                onTap: () => _do(() => _tool = DrawTool.corners),
              ),
              ToolButton(
                icon: AppIcon.undo,
                label: l10n.toolUndo,
                onTap: _editor.canUndo ? () => _do(_editor.undo) : null,
              ),
              ToolButton(
                icon: AppIcon.redo,
                label: l10n.toolRedo,
                onTap: _editor.canRedo ? () => _do(_editor.redo) : null,
              ),
              ToolButton(
                icon: AppIcon.erase,
                label: l10n.toolErase,
                onTap: _editor.isEmpty ? null : () => _do(_editor.erase),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CanvasCard(
              child: OrchardCanvas(
                frame: _frame,
                semanticLabel: l10n.a11yOrchardDrawing,
                outline: _editor.points,
                closed: _editor.closed,
                stroke: _stroke,
                showCorners: true,
                highlightFirst: !_editor.closed && _editor.points.length >= 3,
                gridLabel: l10n.gridSquare,
                northLabel: l10n.north,
                onTap: _tap,
                onDragStart: _dragStart,
                onDrag: _drag,
                onDragEnd: _dragEnd,
                photo: widget.sketch?.image,
                photoPlace: _editor.photo,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // The size (tap to type it) and the area.
          Row(
            children: [
              Expanded(
                child: _SizeChip(
                  title: l10n.widthShort,
                  text: b == null
                      ? '—'
                      : l10n.metres(metresText(b.width.roundToDouble())),
                  label: l10n.widthLabel,
                  onTap: closed ? _size : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SizeChip(
                  title: l10n.lengthShort,
                  text: b == null
                      ? '—'
                      : l10n.metres(metresText(b.length.roundToDouble())),
                  label: l10n.lengthLabel,
                  onTap: closed ? _size : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SizeChip(
                  title: l10n.areaLabel,
                  // A crossed shape has no real area: "—".
                  text: closed && _editor.problem != OutlineProblem.crossing
                      ? l10n.hectaresValue(
                          hectares(_editor.points).toStringAsFixed(2),
                        )
                      : '—',
                  label: l10n.areaLabel,
                  onTap: null,
                  strong: true,
                ),
              ),
            ],
          ),
          if (saveError != null) ...[
            const SizedBox(height: 8),
            AuthNote.failure(saveError),
          ],
        ],
      ),
      bottom: [
        ActionButton(
          label: _saving ? l10n.saving : '★ ${l10n.next}',
          onPressed: _editor.problem == null && !_saving ? _next : null,
        ),
      ],
    );
  }
}

/// "العرض / 195 م": a size of the orchard (tap = type it).
class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.title,
    required this.text,
    required this.label,
    required this.onTap,
    this.strong = false,
  });

  /// The small word above ("العرض").
  final String title;
  final String text;
  final String label;
  final VoidCallback? onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      value: text,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          height: 56,
          color: strong ? AppColors.softGreen : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          shadows: AppShadows.langPill,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.of(
                    12,
                    FontWeight.w700,
                  ).copyWith(color: AppColors.textMuted, height: 1.2),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onTap != null) ...[
                      const LoozIcon(AppIcon.ruler, size: 17),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      text,
                      style: AppTextStyles.of(
                        16,
                        FontWeight.w800,
                      ).copyWith(height: 1.2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
