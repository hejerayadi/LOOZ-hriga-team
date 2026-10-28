// The frame of the main screens (the design's "Shell"):
//  - ShellContent: the scrolling page, with the design's margins,
//  - ShellBars: the assistant bar + the tab bar, floating at the bottom,
//  - ShellPage: both, for a screen opened on top of the tabs.
import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import 'assistant_button.dart';
import 'camera_button.dart';
import 'looz_background.dart';
import 'looz_tab_bar.dart';

/// The content of a page: scrolls under the bottom bars, with enough
/// space at the end to scroll the last card above them.
class ShellContent extends StatelessWidget {
  const ShellContent({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.paddingOf(context);
    final side = AppSpacing.pageSide(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        side,
        system.top + AppSpacing.pageTop,
        side,
        system.bottom + AppSpacing.pageBottom,
      ),
      children: children,
    );
  }
}

/// The 2 bars at the bottom of the screen (put it on top, in a Stack).
class ShellBars extends StatelessWidget {
  const ShellBars({
    super.key,
    required this.selected,
    this.showAssistant = true,
  });

  /// The selected tab (null = none, on screens opened on top).
  final AppTab? selected;

  /// false = only the tab bar (e.g. while a panel of the 3D orchard is open).
  final bool showAssistant;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Above the phone's own buttons / gesture bar, if any.
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    final small = AppSpacing.isSmallPhone(context);
    final assistantWidth = small
        ? size.width - 28
        : (size.width - 40).clamp(0.0, AppSizes.assistantBarMaxWidth);
    final tabBarWidth = (size.width - 24).clamp(0.0, AppSizes.tabBarMaxWidth);
    return Stack(
      children: [
        if (showAssistant)
          Positioned(
            bottom: systemBottom + AppSizes.assistantBarBottom,
            left: (size.width - assistantWidth) / 2,
            width: assistantWidth,
            // Like in the design: the pill on the right, the camera on the left.
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  Expanded(child: AssistantButton()),
                  SizedBox(width: 10),
                  CameraButton(),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: systemBottom + AppSizes.tabBarBottom,
          left: (size.width - tabBarWidth) / 2,
          width: tabBarWidth,
          child: LoozTabBar(selected: selected),
        ),
      ],
    );
  }
}

/// A screen opened on top of the tabs (e.g. an alert): the page and the bars.
class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoozBackground(
        child: Stack(
          children: [
            ShellContent(children: children),
            const Positioned.fill(child: ShellBars(selected: null)),
          ],
        ),
      ),
    );
  }
}
