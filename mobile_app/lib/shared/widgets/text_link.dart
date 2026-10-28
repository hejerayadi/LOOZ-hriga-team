// The design's text button ("ليس الآن"): no background, full width.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class TextLink extends StatelessWidget {
  const TextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Center(
            child: Text(label, style: AppTextStyles.of(17, FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
