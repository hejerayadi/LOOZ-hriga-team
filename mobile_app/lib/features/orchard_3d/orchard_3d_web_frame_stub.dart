// Stand-in for orchard_3d_web_frame.dart on Android / iOS.
// It is never shown there (phones use the WebView), it only lets the app compile.
import 'package:flutter/widgets.dart';

class Orchard3dWebFrame extends StatelessWidget {
  const Orchard3dWebFrame({
    super.key,
    required this.asset,
    required this.data,
    required this.language,
    required this.onMessage,
  });

  final String asset;
  final String data;
  final String language;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
