// "Verger 3D" screen: the 3D orchard planner, with the camera and AI buttons.
import 'package:flutter/material.dart';

import '../../core/plans.dart';
import '../../core/strings/app_strings.dart';
import '../../shared/widgets/looz_scaffold.dart';
import '../plans/plans_screen.dart';
import 'orchard_3d_data.dart';
import 'orchard_3d_view.dart';

class Orchard3dPage extends StatefulWidget {
  const Orchard3dPage({super.key});

  @override
  State<Orchard3dPage> createState() => _Orchard3dPageState();
}

class _Orchard3dPageState extends State<Orchard3dPage> {
  // false while the 3D page's settings panel covers the bottom of a
  // small screen, so the 2 big buttons do not hide its sliders.
  bool _showButtons = true;

  // The orchard (zones, nodes, trees) sent to the 3D page. Fake for now.
  // Live zone data (nodes, readings) only with the "Connecté" plan.
  final String _orchardJson = orchard3dJson(
    liveData: canUse(Feature.liveZoneData),
  );

  /// Messages sent by the 3D page (assets/orchard_3d/index.html).
  void _onMessage(String message) {
    // "Passer à Connecté" tapped in the zone panel.
    if (message == 'looz:upgrade') {
      openPlans(context);
      return;
    }
    final show = switch (message) {
      'looz:buttons:hide' => false,
      'looz:buttons:show' => true,
      _ => null,
    };
    if (show != null && show != _showButtons) {
      setState(() => _showButtons = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoozScaffold(
      title: AppStrings.orchard3d,
      showButtons: _showButtons,
      body: Orchard3dView(data: _orchardJson, onMessage: _onMessage),
    );
  }
}
