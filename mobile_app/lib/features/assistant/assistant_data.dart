// FAKE chat messages for the AI assistant (no real AI yet).

/// One message in the chat.
class ChatMessage {
  const ChatMessage({required this.text, required this.fromUser});

  final String text;

  /// true = written by the farmer, false = written by the assistant.
  final bool fromUser;
}

const List<ChatMessage> fakeMessages = [
  ChatMessage(
    text: 'Bonjour ! Comment va votre verger ?',
    fromUser: false,
  ),
  ChatMessage(
    text: 'Les feuilles de l\'arbre 7 jaunissent.',
    fromUser: true,
  ),
  ChatMessage(
    text: 'Le sol est sec. Arrosez ce soir. Envoyez-moi une photo 📷',
    fromUser: false,
  ),
];
