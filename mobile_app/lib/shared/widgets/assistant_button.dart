// Big round AI assistant button: opens the chat screen.
import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../features/assistant/assistant_screen.dart';

class AssistantButton extends StatelessWidget {
  const AssistantButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.large(
      heroTag: 'assistant',
      tooltip: AppStrings.assistant,
      backgroundColor: AppColors.brown,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AssistantScreen()),
        );
      },
      child: const Icon(Icons.smart_toy, size: 44),
    );
  }
}
