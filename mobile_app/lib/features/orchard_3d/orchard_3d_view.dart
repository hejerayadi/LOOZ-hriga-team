// Shows assets/orchard_3d/index.html (the 3D scene):
//  - Android / iOS: inside a WebView,
//  - Flutter web (Chrome): inside an iframe (WebView does not exist there).
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';
// The iframe code only compiles for the web, so phones get an empty stand-in.
import 'orchard_3d_web_frame_stub.dart'
    if (dart.library.js_interop) 'orchard_3d_web_frame.dart';

/// The 3D page, inside the app assets.
const orchard3dAsset = 'assets/orchard_3d/index.html';

class Orchard3dView extends StatelessWidget {
  const Orchard3dView({super.key, required this.onMessage});

  /// Called with each message the 3D page sends (e.g. 'looz:buttons:hide').
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    // kIsWeb = true when the app runs in a browser (Chrome).
    return kIsWeb
        ? Orchard3dWebFrame(asset: orchard3dAsset, onMessage: onMessage)
        : _Orchard3dWebView(onMessage: onMessage);
  }
}

class _Orchard3dWebView extends StatefulWidget {
  const _Orchard3dWebView({required this.onMessage});

  final ValueChanged<String> onMessage;

  @override
  State<_Orchard3dWebView> createState() => _Orchard3dWebViewState();
}

class _Orchard3dWebViewState extends State<_Orchard3dWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // three.js needs JavaScript.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.almond)
      // The page talks to Flutter with LoozFlutter.postMessage('...').
      ..addJavaScriptChannel(
        'LoozFlutter',
        onMessageReceived: (message) => widget.onMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadFlutterAsset(orchard3dAsset);
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
