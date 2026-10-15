// A small colored "pill" with text, e.g. "Expert" or "Premium".
import 'package:flutter/material.dart';

class BadgeLabel extends StatelessWidget {
  const BadgeLabel({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;

  /// Optional small icon before the text.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
