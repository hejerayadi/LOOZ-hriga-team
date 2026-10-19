// Flutter web only: shows the 3D page in an <iframe>, and listens to the
// messages it sends with window.parent.postMessage('looz:...').
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class Orchard3dWebFrame extends StatefulWidget {
  const Orchard3dWebFrame({
    super.key,
    required this.asset,
    required this.onMessage,
  });

  /// Asset path of the page, e.g. 'assets/orchard_3d/index.html'.
  final String asset;

  /// Called with each 'looz:...' message the page sends.
  final ValueChanged<String> onMessage;

  @override
  State<Orchard3dWebFrame> createState() => _Orchard3dWebFrameState();
}

class _Orchard3dWebFrameState extends State<Orchard3dWebFrame> {
  // Kept in a variable so the same listener can be removed in dispose().
  late final JSFunction _listener = _onMessage.toJS;

  @override
  void initState() {
    super.initState();
    _window.addEventListener('message', _listener);
  }

  @override
  void dispose() {
    _window.removeEventListener('message', _listener);
    super.dispose();
  }

  void _onMessage(_MessageEvent event) {
    final data = event.data;
    if (!data.isA<JSString>()) return;
    final text = (data as JSString).toDart;
    // Ignore messages that do not come from the 3D page.
    if (text.startsWith('looz:')) widget.onMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (element) {
        final frame = element as _IFrame;
        // Flutter web serves the assets under its own URL: ask for it.
        frame.src = ui_web.assetManager.getAssetUrl(widget.asset);
        frame.style
          ..border = 'none'
          ..width = '100%'
          ..height = '100%';
      },
    );
  }
}

// Small bindings to the browser objects we need (window, iframe, message).
@JS('window')
external _Window get _window;

extension type _Window(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _MessageEvent(JSObject _) implements JSObject {
  external JSAny? get data;
}

extension type _IFrame(JSObject _) implements JSObject {
  external set src(String value);
  external _Style get style;
}

extension type _Style(JSObject _) implements JSObject {
  external set border(String value);
  external set width(String value);
  external set height(String value);
}
