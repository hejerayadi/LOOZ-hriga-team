// A colored circle: green = good, orange = warning, red = danger.
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/theme/app_theme.dart';

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.level, this.size = 24});

  final StatusLevel level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.forLevel(level),
        shape: BoxShape.circle,
      ),
    );
  }
}
