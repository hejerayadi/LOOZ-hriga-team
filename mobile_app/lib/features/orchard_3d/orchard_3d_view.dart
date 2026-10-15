// The WebView that shows assets/orchard_3d/index.html (the 3D scene).
// Only used on Android / iOS: WebView does not exist on Flutter web.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';
import 'orchard_3d_data.dart';

class Orchard3dView extends StatefulWidget {
  const Orchard3dView({super.key});

  @override
  State<Orchard3dView> createState() => _Orchard3dViewState();
}

class _Orchard3dViewState extends State<Orchard3dView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // three.js needs JavaScript.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.almond)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            // The page is ready: send it the trees (positions + health).
            await _controller.runJavaScript(
              'window.loozSetTrees(${orchardJson()});',
            );
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadFlutterAsset('assets/orchard_3d/index.html');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(
          controller: _controller,
          // Give ALL touch gestures to the 3D scene (rotate, pinch...).
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
