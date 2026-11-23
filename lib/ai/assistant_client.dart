import 'message_builder.dart';

/// The wire protocol a provider speaks.
enum AiProtocol {
  /// Anthropic Messages API.
  anthropic,

  /// OpenAI chat-completions, which Groq, Gemini and Grok all also speak.
  openai,
}

/// Which AI service the assistant uses. Groq is free; the rest take the
/// user's own key, and [custom] takes any OpenAI-compatible endpoint. The
/// [model] here is the default; the user can override it in Settings.
enum AiProvider {
  groq(
    label: 'Groq (free)',
    keyPrefix: 'gsk_',
    consoleUrl: 'console.groq.com/keys',
    model: 'openai/gpt-oss-120b',
    endpoint: 'https://api.groq.com/openai/v1/chat/completions',
    protocol: AiProtocol.openai,
    blurb: 'Fast, with per-minute limits',
  ),
  gemini(
    label: 'Google Gemini',
    keyPrefix: 'AIza',
    consoleUrl: 'aistudio.google.com/apikey',
    model: 'gemini-3.8-flash',
    endpoint:
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    protocol: AiProtocol.openai,
    blurb: 'Google, with a free tier',
  ),
  grok(
    label: 'xAI Grok',
    keyPrefix: 'xai-',
    consoleUrl: 'console.x.ai',
    model: 'grok-4.7',
    endpoint: 'https://api.x.ai/v1/chat/completions',
    protocol: AiProtocol.openai,
    blurb: 'xAI, witty and fast',
  ),
  claude(
    label: 'Claude',
    keyPrefix: 'sk-ant-',
    consoleUrl: 'console.anthropic.com',
    model: 'claude-opus-5-5',
    endpoint: 'https://api.anthropic.com/v1/messages',
    protocol: AiProtocol.anthropic,
    blurb: 'The most capable',
  ),
  custom(
    label: 'Custom',
    keyPrefix: '',
    consoleUrl: 'your provider',
    model: '',
    endpoint: '',
    protocol: AiProtocol.openai,
    blurb: 'Any OpenAI-compatible API',
  );

  const AiProvider({
    required this.label,
    required this.keyPrefix,
    required this.consoleUrl,
    required this.model,
    required this.endpoint,
    required this.protocol,
    required this.blurb,
  });

  final String label;
  final String keyPrefix;
  final String consoleUrl;

  /// Default model id. The user can override it per provider in Settings.
  final String model;

  /// Default chat-completions URL. For [custom] the user supplies it.
  final String endpoint;
  final AiProtocol protocol;

  /// One-line description shown on the provider card.
  final String blurb;

  /// Groq ships a built-in key, so it's the only free-to-start option.
  bool get freeToStart => this == AiProvider.groq;

  /// Takes a user-supplied endpoint (and so needs one before it can be used).
  bool get needsEndpoint => this == AiProvider.custom;

  /// Rough check that catches pasting the wrong thing; the service has the
  /// final say. Custom providers have no known prefix, so any non-empty key
  /// is accepted.
  bool looksLikeKey(String key) {
    final k = key.trim();
    if (keyPrefix.isEmpty) return k.isNotEmpty;
    return k.startsWith(keyPrefix) && k.length > 20;
  }
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
