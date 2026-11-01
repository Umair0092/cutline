import 'message_builder.dart';

/// Which AI service the assistant uses.
enum AiProvider {
  groq(
    label: 'Groq (free)',
    keyPrefix: 'gsk_',
    consoleUrl: 'console.groq.com/keys',
    model: 'openai/gpt-oss-120b',
  ),
  claude(
    label: 'Claude',
    keyPrefix: 'sk-ant-',
    consoleUrl: 'console.anthropic.com',
    model: 'claude-opus-5-5',
  );

  const AiProvider({
    required this.label,
    required this.keyPrefix,
    required this.consoleUrl,
    required this.model,
  });

  final String label;
  final String keyPrefix;
  final String consoleUrl;
  final String model;

  /// Rough check that catches pasting the wrong thing; the service has the
  /// final say.
  bool looksLikeKey(String key) =>
      key.trim().startsWith(keyPrefix) && key.trim().length > 20;
}

/// A failed request, with a message fit to show in the chat.
class AssistantException implements Exception {
  AssistantException(this.message, {this.statusCode, this.retryable = false});

  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => message;
}

/// Sends the conversation (kept in the Messages API format: content blocks,
/// tool_use, tool_result) and streams the reply as it's built.
abstract class AssistantClient {
  Stream<MessageBuilder> stream({
    required List<Map<String, dynamic>> system,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools = const [],
  });

  void close();
}
