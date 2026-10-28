// The big pill button of the design: text + an arrow, full width.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';
import 'css_box.dart';
import 'symbol_text.dart';

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });

  /// The text (may contain ★).
  final String label;

  /// null = not ready yet (e.g. the phone number is not complete):
  /// the button is shown faded and does nothing.
  final VoidCallback? onPressed;

  /// true = the paler green of the second buttons.
  final bool secondary;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  // Like in the design, the button shrinks a little while pressed.
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed != null && value != _pressed) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 200),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: CssBox(
              minHeight: 64,
              color: widget.secondary
                  ? AppColors.softGreen
                  : AppColors.lightGreen,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              shadows: AppShadows.button,
              highlight: AppHighlights.button,
              highlightColor: AppHighlights.buttonColor,
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: SymbolText(
                      widget.label,
                      style: AppTextStyles.button,
                    ),
                  ),
                  // The design's arrow points right in both languages.
                  const LoozIcon(AppIcon.arrow, size: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
