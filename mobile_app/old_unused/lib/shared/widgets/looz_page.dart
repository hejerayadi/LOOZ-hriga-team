// The old layout of the tab pages not redesigned yet (Community, Alerts,
// Profile): logo, big title, then the cards. The bottom bars come from the
// main screen (MainShell). Replaced by the design's screens in step 3.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'looz_logo.dart';
import 'looz_scaffold.dart';
import 'screen_title.dart';

class LoozPage extends StatelessWidget {
  const LoozPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.showLogo = false,
  });

  /// Big text shown at the top of the page.
  final String title;

  /// Line under the title (null = none).
  final String? subtitle;

  /// true = the Looz logo above the title.
  final bool showLogo;

  /// The content of the page (cards, lists...).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final side = AppSpacing.pageSide(context);
    return LoozScaffold(
      showButtons: false,
      body: ListView(
        // Extra space at the bottom so the assistant bar and the tab bar
        // never hide the content.
        padding: EdgeInsets.fromLTRB(
          side,
          padding.top + AppSpacing.pageTop,
          side,
          padding.bottom + AppSpacing.pageBottom,
        ),
        children: [
          if (showLogo)
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: LoozLogo(),
            ),
          ScreenTitle(title: title, subtitle: subtitle),
          ...children,
        ],
      ),
    );
  }
}
