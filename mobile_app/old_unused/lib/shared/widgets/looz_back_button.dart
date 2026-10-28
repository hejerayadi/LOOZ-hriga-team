// Round white "back" button, for pages opened on top of the tabs.
import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';

class LoozBackButton extends StatelessWidget {
  const LoozBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppStrings.back,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppShadows.small,
        ),
        child: Material(
          color: AppColors.glass,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox.square(
              dimension: AppSizes.backButton,
              child: Icon(Icons.arrow_back_rounded, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
