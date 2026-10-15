// The common frame of every screen: a title at the top, any content
// in the middle, and the 2 big buttons (AI assistant + camera) at the
// bottom right.
import 'package:flutter/material.dart';

import 'assistant_button.dart';
import 'camera_button.dart';

class LoozScaffold extends StatelessWidget {
  const LoozScaffold({super.key, required this.title, required this.body});

  /// Text shown at the top of the screen.
  final String title;

  /// The content of the screen.
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
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
