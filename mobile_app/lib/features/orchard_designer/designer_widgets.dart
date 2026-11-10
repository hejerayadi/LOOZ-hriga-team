// The pieces of the designer's screens, in the design's style: the page
// (back button, "الخطوة 1 من 3", title), the round tools with a word under
// the icon, the big choice cards, the number boxes and the size sheet.
// Big targets (at least 48 points) for fingers; they work with a mouse too.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validators.dart';
import '../../data/orchard_design.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_background.dart';
import 'orchard_canvas.dart';

/// The 3 steps: draw, zones, review.
const designerSteps = 3;

/// A step of the designer (no tab bar: drawing needs the whole screen).
class DesignerPage extends StatelessWidget {
  const DesignerPage({
    super.key,
    required this.step,
    required this.title,
    required this.body,
    this.hint,
    this.bottom = const [],
  });

  /// 1, 2 or 3.
  final int step;
  final String title;

  /// One short line under the title (or a problem).
  final Widget? hint;
  final Widget body;

  /// The buttons at the bottom (always visible).
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.paddingOf(context);
    final side = AppSpacing.pageSide(context);
    final small =
        AppSpacing.isSmallPhone(context) ||
        MediaQuery.sizeOf(context).height < 700;
    return Scaffold(
      body: LoozBackground(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            side,
            system.top + (small ? 10 : 18),
            side,
            system.bottom + (small ? 10 : 18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(step: step),
              SizedBox(height: small ? 6 : 12),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppTextStyles.of(small ? 23 : 27, FontWeight.w800),
                ),
              ),
              if (hint != null) ...[const SizedBox(height: 4), hint!],
              SizedBox(height: small ? 8 : 12),
              Expanded(child: body),
              for (final w in bottom) ...[SizedBox(height: small ? 8 : 10), w],
            ],
          ),
        ),
      ),
    );
  }
}

/// The back button and "الخطوة 1 من 3" with 3 dots.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: [
        Semantics(
          button: true,
          label: l10n.back,
          child: GestureDetector(
            key: const ValueKey('designer-back'),
            onTap: () => Navigator.of(context).maybePop(),
            child: CssBox(
              width: 52,
              height: 52,
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              shadows: AppShadows.langPill,
              alignment: Alignment.center,
              // The arrow points right: "back" in Arabic, mirrored in French.
              child: Transform.flip(
                flipX: !rtl,
                child: const LoozIcon(AppIcon.arrow, size: 26),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            l10n.designerStepOf(step, designerSteps),
            style: AppTextStyles.of(16, FontWeight.w700),
          ),
        ),
        for (var i = 1; i <= designerSteps; i++)
          Container(
            width: i == step ? 26 : 10,
            height: 10,
            margin: const EdgeInsetsDirectional.only(start: 6),
            decoration: BoxDecoration(
              color: i <= step ? AppColors.leaf : AppColors.mint,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}

/// A round tool with a word under it ("تراجع"): for people who read little,
/// the icon and the word go together.
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final AppIcon icon;
  final String label;

  /// null = not possible now (faded).
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: SizedBox(
            width: 62,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CssBox(
                  width: 50,
                  height: 50,
                  color: selected ? AppColors.green : AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  shadows: AppShadows.langPill,
                  alignment: Alignment.center,
                  child: LoozIcon(
                    icon,
                    size: 25,
                    color: selected ? AppColors.white : AppColors.green,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.of(13, FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A big white card to choose something (an icon, a title, a line).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.trailing,
  });

  final AppIcon icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          minHeight: 88,
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          shadows: AppShadows.card,
          border: Border.all(
            color: selected ? AppColors.leaf : AppColors.white,
            width: 2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              IconBlob(icon: icon, size: 54, iconSize: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTextStyles.of(18, FontWeight.w800)),
                    if (subtitle != null)
                      Text(subtitle!, style: AppTextStyles.of(15)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// "قريبًا" in a small pill.
class SoonPill extends StatelessWidget {
  const SoonPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        context.l10n.soon,
        style: AppTextStyles.of(13, FontWeight.w800),
      ),
    );
  }
}

/// A short line under the title: a help, or a problem (with ▲!).
class HintLine extends StatelessWidget {
  const HintLine(this.text, {super.key, this.problem = false});

  final String text;
  final bool problem;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.of(
      16,
      problem ? FontWeight.w800 : FontWeight.w600,
    );
    return Semantics(
      liveRegion: problem,
      child: Row(
        children: [
          if (problem) ...[
            const LoozIcon(AppIcon.warning, size: 22, color: AppColors.danger),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Opacity(
              opacity: problem ? 1 : 0.75,
              child: Text(text, style: style),
            ),
          ),
        ],
      ),
    );
  }
}

/// The white card that holds a drawing.
class CanvasCard extends StatelessWidget {
  const CanvasCard({super.key, required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return CssBox(
      height: height,
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      shadows: AppShadows.card,
      clip: true,
      child: child,
    );
  }
}

/// The colour and letter of a zone.
class ZoneDot extends StatelessWidget {
  const ZoneDot({super.key, required this.zone, this.size = 40});

  final DesignZone zone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorOf(zone.color),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Text(
        zone.letter,
        textDirection: TextDirection.ltr,
        style: AppTextStyles.of(
          size * 0.45,
          FontWeight.w800,
        ).copyWith(color: AppColors.white),
      ),
    );
  }
}

/// "المنطقة A" or the farmer's name for it.
String zoneTitle(AppLocalizations l10n, DesignZone zone) =>
    zone.name.trim().isEmpty ? l10n.zoneName(zone.letter) : zone.name.trim();

/// A number typed by the farmer (Arabic digits too), or null.
int? parseWhole(String text) => int.tryParse(westernDigits(text.trim()));

/// A white box for a number (trees, metres): big digits, left to right.
class NumberBox extends StatelessWidget {
  const NumberBox({
    super.key,
    required this.controller,
    this.onChanged,
    this.error = false,
    this.width,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool error;
  final double? width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: AppShadows.langPill,
        border: Border.all(
          color: error ? AppColors.danger : AppColors.mint,
          width: 2,
        ),
      ),
      // Only the name of the box: the TextField itself is the text field
      // (a second "textField" here = two boxes for a screen reader).
      child: Semantics(
        label: semanticLabel,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: AppTextStyles.of(21, FontWeight.w800),
          cursorColor: AppColors.green,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]')),
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

/// The size of the orchard (metres): the sheet with two boxes.
/// Returns (width, length), or null when closed without "تمّ".
Future<(double, double)?> showSizeSheet(
  BuildContext context, {
  required double width,
  required double length,
}) => showModalBottomSheet<(double, double)>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.cream,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
  ),
  builder: (context) => _SizeSheet(width: width, length: length),
);

/// The sizes the boxes accept (metres).
const minSide = 5;
const maxSide = 3000;

class _SizeSheet extends StatefulWidget {
  const _SizeSheet({required this.width, required this.length});

  final double width;
  final double length;

  @override
  State<_SizeSheet> createState() => _SizeSheetState();
}

class _SizeSheetState extends State<_SizeSheet> {
  late final _width = TextEditingController(text: '${widget.width.round()}');
  late final _length = TextEditingController(text: '${widget.length.round()}');
  bool _tried = false;

  @override
  void dispose() {
    _width.dispose();
    _length.dispose();
    super.dispose();
  }

  bool _ok(TextEditingController c) {
    final v = parseWhole(c.text);
    return v != null && v >= minSide && v <= maxSide;
  }

  void _done() {
    setState(() => _tried = true);
    if (!_ok(_width) || !_ok(_length)) return;
    Navigator.of(context).pop((
      parseWhole(_width.text)!.toDouble(),
      parseWhole(_length.text)!.toDouble(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget field(String label, AppIcon icon, TextEditingController c) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              IconBlob(icon: icon, size: 48, iconSize: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.of(16, FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              NumberBox(
                controller: c,
                width: 110,
                error: _tried && !_ok(c),
                semanticLabel: label,
                onChanged: (_) => _tried ? setState(() {}) : null,
              ),
            ],
          ),
        );
    final wrong = _tried && (!_ok(_width) || !_ok(_length));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.sizeTitle, style: AppTextStyles.of(22, FontWeight.w800)),
          const SizedBox(height: 14),
          field(l10n.widthLabel, AppIcon.ruler, _width),
          field(l10n.lengthLabel, AppIcon.ruler, _length),
          if (wrong) ...[
            HintLine(l10n.sizeInvalid(minSide, maxSide), problem: true),
            const SizedBox(height: 10),
          ],
          ActionButton(label: l10n.done, onPressed: _done),
        ],
      ),
    );
  }
}

/// "هل تمسح رسمك وتبدأ من جديد؟": "امسح" / "إلغاء" (true = erase).
Future<bool> confirmErase(BuildContext context) async {
  final l10n = context.l10n;
  final answer = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          shadows: AppShadows.card,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.drawAgainQuestion,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(20, FontWeight.w800),
              ),
              const SizedBox(height: 20),
              ActionButton(
                label: l10n.eraseAction,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 12),
              ActionButton(
                label: l10n.cancelAction,
                secondary: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return answer ?? false;
}
