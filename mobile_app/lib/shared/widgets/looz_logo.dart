// The LOOZ logo (assets/images/), in a 48 x 72 box like in the design.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';

class LoozLogo extends StatelessWidget {
  const LoozLogo({super.key, this.white = false});

  /// true = the white logo, for the photo of the first screen.
  final bool white;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.logoWidth,
      height: AppSizes.logoHeight,
      child: Image.asset(
        white
            ? 'assets/images/looz_logo_white.png'
            : 'assets/images/looz_logo.png',
        fit: BoxFit.contain,
        semanticLabel: context.l10n.appName,
      ),
    );
  }
}
