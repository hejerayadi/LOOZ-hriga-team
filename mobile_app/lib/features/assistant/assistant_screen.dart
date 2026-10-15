// Simple chat screen with the AI assistant (fake answers for now).
import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'assistant_data.dart';

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

  /// Adds the user's message, then a fake reply from the assistant.
  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
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
          // The text field + send button at the bottom.
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
