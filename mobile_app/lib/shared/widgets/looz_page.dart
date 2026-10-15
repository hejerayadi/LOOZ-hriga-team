// The layout used by the tab pages: LoozScaffold (title + the 2 big
// buttons) with a scrolling list of cards inside.
import 'package:flutter/material.dart';

import 'looz_scaffold.dart';

class LoozPage extends StatelessWidget {
  const LoozPage({super.key, required this.title, required this.children});

  /// Text shown at the top of the page.
  final String title;

  /// The content of the page (cards, lists...).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LoozScaffold(
      title: title,
      body: ListView(
        // Extra space at the bottom so the 2 buttons never hide the content.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 240),
        children: children,
      ),
    );
  }
}
