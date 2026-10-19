// Simple chat screen with the AI assistant (fake answers for now).
import 'package:flutter/material.dart';

import '../../core/plans.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/locked_feature.dart';
import 'assistant_data.dart';

// Questions asked today (free plan: limited per day, see core/plans.dart).
// FAKE count, kept only while the app is open. Later the server will count
// them, so the limit cannot be bypassed by restarting the app.
int _questionsToday = 0;
DateTime _countDay = DateTime.now();

int _questionsAskedToday() {
  final now = DateTime.now();
  if (now.year != _countDay.year ||
      now.month != _countDay.month ||
      now.day != _countDay.day) {
    _questionsToday = 0; // a new day: start again
    _countDay = now;
  }
  return _questionsToday;
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  // Copy the fake messages into a list we can add to.
  final List<ChatMessage> _messages = [...fakeMessages];

  // Reads what the user types in the text field.
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Questions left today (null = no limit in this plan).
  int? _questionsLeft() {
    final limit = assistantDailyLimit();
    return limit == null
        ? null
        : (limit - _questionsAskedToday()).clamp(0, limit);
  }

  /// Adds the user's message, then a fake reply from the assistant.
  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || _questionsLeft() == 0) return;
    setState(() {
      _questionsToday = _questionsAskedToday() + 1;
      _messages.add(ChatMessage(text: text, fromUser: true));
      _messages.add(
        const ChatMessage(text: AppStrings.assistantFakeReply, fromUser: false),
      );
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.assistant)),
      body: Column(
        children: [
          // The list of messages.
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _MessageBubble(message: _messages[index]),
            ),
          ),
          // Free plan: questions left today, or the upgrade button when none.
          ValueListenableBuilder<Plan>(
            valueListenable: currentPlan,
            builder: (context, plan, _) => _QuotaBar(left: _questionsLeft()),
          ),
          // The text field + send button at the bottom.
          if (_questionsLeft() != 0)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 18),
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: AppStrings.assistantHint,
                          filled: true,
                          fillColor: AppColors.almondLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      iconSize: 32,
                      tooltip: AppStrings.send,
                      onPressed: _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Free plan: "Reste 7 questions aujourd'hui", or, at 0, a lock and the
/// "Passer à Essentiel" button. Nothing on paid plans (left == null).
class _QuotaBar extends StatelessWidget {
  const _QuotaBar({required this.left});

  final int? left;

  @override
  Widget build(BuildContext context) {
    final left = this.left;
    if (left == null) return const SizedBox.shrink();
    if (left > 0) {
      return Text(
        AppStrings.assistantQuestionsLeft(left),
        style: const TextStyle(fontSize: 16, color: AppColors.brown),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 32, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  AppStrings.assistantLimitReached,
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const UpgradeButton(plan: Plan.essential),
          ],
        ),
      ),
    );
  }
}

/// One chat bubble: user on the right (olive), assistant on the left (white).
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: fromUser ? AppColors.olive : AppColors.almondLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 18,
            color: fromUser ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
