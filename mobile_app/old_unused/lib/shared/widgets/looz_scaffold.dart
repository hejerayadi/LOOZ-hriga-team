// The common frame of every main screen: the design's background, any
// content, and the 2 big buttons (AI assistant + camera) at the bottom.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'assistant_button.dart';
import 'camera_button.dart';
import 'looz_back_button.dart';
import 'looz_background.dart';

class LoozScaffold extends StatelessWidget {
  const LoozScaffold({
    super.key,
    required this.body,
    this.title,
    this.showButtons = true,
    this.compactButtons = false,
  });

  /// The content of the screen.
  final Widget body;

  /// Shown in a small top bar with a back button (for pages opened on top,
  /// like the 3D orchard). null = no top bar: the page shows its own big
  /// title (see LoozPage).
  final String? title;

  /// false = hide the 2 big buttons for a moment (e.g. while a panel
  /// of the 3D orchard covers the bottom of the screen).
  final bool showButtons;

  /// true = 2 round buttons on the right instead of the wide bar, so they
  /// do not hide what is at the bottom left (the 3D orchard's walk arrows).
  final bool compactButtons;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    // Inside the tabs, this padding already includes the floating tab bar.
    final bottom = MediaQuery.paddingOf(context).bottom + AppSpacing.md;
    final side = AppSpacing.pageSide(context);
    return Scaffold(
      body: LoozBackground(
        child: Stack(
          children: [
            Column(
              children: [
                if (title != null) _TopBar(title: title),
                Expanded(child: body),
              ],
            ),
            if (showButtons && compactButtons)
              Positioned(
                right: AppSpacing.lg,
                bottom: bottom,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssistantButton(compact: true),
                    SizedBox(height: AppSpacing.md),
                    CameraButton(),
                  ],
                ),
              )
            else if (showButtons)
              Positioned(
                left: side,
                right: side,
                bottom: bottom,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: const Row(
                      children: [
                        Expanded(child: AssistantButton()),
                        SizedBox(width: 10),
                        CameraButton(),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Back button + title, for pages opened on top of the tabs.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final side = AppSpacing.pageSide(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, AppSpacing.md, side, AppSpacing.sm),
        child: Row(
          children: [
            if (Navigator.of(context).canPop()) ...[
              const LoozBackButton(),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
