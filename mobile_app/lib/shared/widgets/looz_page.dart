// The common layout used by EVERY tab page:
// a title at the top, a scrolling list, and the 2 big buttons
// (AI assistant + camera) at the bottom right.
import 'package:flutter/material.dart';

import 'assistant_button.dart';
import 'camera_button.dart';

class LoozPage extends StatelessWidget {
  const LoozPage({super.key, required this.title, required this.children});

  /// Text shown at the top of the page.
  final String title;

  /// The content of the page (cards, lists...).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        // Extra space at the bottom so the 2 buttons never hide the content.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 240),
        children: children,
      ),
      floatingActionButton: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AssistantButton(),
          SizedBox(height: 16),
          CameraButton(),
        ],
      ),
    );
  }
}
