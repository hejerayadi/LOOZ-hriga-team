// The top of the login screens, Home and Profile: the logo and the
// language switch (the logo is on the right in Arabic, on the left in French).
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'lang_pill.dart';
import 'looz_logo.dart';

class LoozHeader extends StatelessWidget {
  const LoozHeader({super.key, this.white = false});

  /// true = the white logo (on the photo of the first screen).
  final bool white;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.logoHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LoozLogo(white: white),
          const LangPill(),
        ],
      ),
    );
  }
}
