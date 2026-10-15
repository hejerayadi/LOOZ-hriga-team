// "Verger 3D" screen: the orchard in 3D, with the camera and AI buttons.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/looz_scaffold.dart';
import 'orchard_3d_view.dart';

class Orchard3dPage extends StatelessWidget {
  const Orchard3dPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LoozScaffold(
      title: AppStrings.orchard3d,
      // kIsWeb = true when the app runs in a browser (Chrome).
      // WebView does not work there, so we show a simple message instead.
      body: kIsWeb ? const _WebOnlyMessage() : const Orchard3dView(),
    );
  }
}

class _WebOnlyMessage extends StatelessWidget {
  const _WebOnlyMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone_android, size: 100, color: AppColors.olive),
          const SizedBox(height: 16),
          Text(
            AppStrings.orchard3dMobileOnly,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
