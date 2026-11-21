// Shows assets/orchard_3d/index.html (the 3D scene):
//  - Android / iOS: inside a WebView,
//  - Flutter web (Chrome): inside an iframe (WebView does not exist there).
import 'dart:convert';

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

/// The page says 'looz:ready' when it has loaded: we answer with the data.
const orchard3dReady = 'looz:ready';

class Orchard3dView extends StatelessWidget {
  const Orchard3dView({
    super.key,
    required this.data,
    required this.language,
    required this.onMessage,
    this.live,
    this.focus,
  });

  /// The orchard as JSON text (see orchard_3d_data.dart).
  final String data;

  /// The live state of the zones as JSON (orchardLiveJson), sent again each
  /// time it changes. null = none yet.
  final String? live;

  /// The zone to show highlighted (a tap on an alert), null = none.
  final String? focus;

  /// 'ar' or 'fr': the page shows its texts in this language, and switches
  /// as soon as it changes.
  final String language;

  /// Called with each other message the 3D page sends
  /// (e.g. 'looz:buttons:hide').
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    // No WebView on this platform (e.g. Windows / Linux desktop, or the
    // tests): an empty frame instead of a crash.
    if (!kIsWeb && WebViewPlatform.instance == null) {
      return const SizedBox.expand();
    }
    // kIsWeb = true when the app runs in a browser (Chrome).
    return kIsWeb
        ? Orchard3dWebFrame(
            asset: orchard3dAsset,
            data: data,
            language: language,
            onMessage: onMessage,
            live: live,
            focus: focus,
          )
        : _Orchard3dWebView(
            data: data,
            language: language,
            onMessage: onMessage,
            live: live,
            focus: focus,
          );
  }
}

class _Orchard3dWebView extends StatefulWidget {
  const _Orchard3dWebView({
    required this.data,
    required this.language,
    required this.onMessage,
    this.live,
    this.focus,
  });

  final String data;
  final String language;
  final ValueChanged<String> onMessage;
  final String? live;
  final String? focus;

  @override
  State<_Orchard3dWebView> createState() => _Orchard3dWebViewState();
}

class _Orchard3dWebViewState extends State<_Orchard3dWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  // true once the page got the data (then it can change language).
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // three.js needs JavaScript.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.cream)
      // The page talks to Flutter with LoozFlutter.postMessage('...').
      ..addJavaScriptChannel(
        'LoozFlutter',
        onMessageReceived: (message) {
          if (message.message == orchard3dReady) {
            _controller.runJavaScript('window.loozSetOrchard(${widget.data});');
            _ready = true;
            _sendLive();
          } else {
            widget.onMessage(message.message);
          }
        },
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

  void _sendLive() {
    final live = widget.live;
    if (live != null) _controller.runJavaScript('window.loozSetLive($live);');
    final focus = widget.focus;
    if (focus != null) _controller.runJavaScript('window.loozFocusZone(${jsonEncode(focus)});');
  }

  @override
  void didUpdateWidget(_Orchard3dWebView old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    if (old.language != widget.language) {
      _controller.runJavaScript(
        "window.loozSetLanguage('${widget.language}');",
      );
    }
    if (old.live != widget.live || old.focus != widget.focus) _sendLive();
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
