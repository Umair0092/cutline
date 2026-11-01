import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'message_builder.dart';
import 'sse.dart';

/// Model and request settings in one place.
abstract final class ClaudeConfig {
  static const endpoint = 'https://api.anthropic.com/v1/messages';
  static const apiVersion = '2026-10-21';
  static const model = 'claude-opus-5-5';
  static const maxTokens = 64000;

  /// Opus 5.5 defaults to medium; set explicitly so behaviour doesn't change
  /// if the default does.
  static const effort = 'medium';

  /// Retry a request the model declines on Anthropic's recommended fallback
  /// model, on the server, instead of returning the refusal.
  static const fallbackBeta = 'server-side-fallback-2026-07-01';
}

/// A failed request, with a message fit to show in the chat.
class ClaudeException implements Exception {
  ClaudeException(this.message, {this.statusCode, this.retryable = false});

  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => message;
}

/// Calls the Messages API over HTTP (there's no official Dart SDK) and
/// streams the reply.
class ClaudeClient {
  ClaudeClient({required this.apiKey, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _http;

  static const maxRetries = 2;

  /// Sends one request and streams the assistant message as it's built.
  /// Each event is the same [MessageBuilder], updated; the stream ends when
  /// the message is complete. Rate limits, overloads, server and network
  /// errors are retried twice before the stream starts.
  Stream<MessageBuilder> stream({
    required List<Map<String, dynamic>> system,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools = const [],
  }) async* {
    final body = jsonEncode({
      'model': ClaudeConfig.model,
      'max_tokens': ClaudeConfig.maxTokens,
      'stream': true,
      'thinking': {'type': 'adaptive'},
      'output_config': {'effort': ClaudeConfig.effort},
      'fallbacks': 'default',
      // Caches everything up to the last message, so long chats stay cheap.
      'cache_control': {'type': 'ephemeral'},
      'system': system,
      if (tools.isNotEmpty) 'tools': tools,
      'messages': messages,
    });

    final response = await _send(body);
    final builder = MessageBuilder();
    await for (final event in parseSse(response.stream)) {
      if (event.event == 'ping') continue;
      final data = jsonDecode(event.data) as Map<String, dynamic>;
      if (data['type'] == 'error') {
        final error = data['error'] as Map<String, dynamic>? ?? const {};
        throw _errorFor(
          null,
          error['type'] as String?,
          error['message'] as String?,
        );
      }
      final done = builder.add(data);
      yield builder;
      if (done) return;
    }
    throw ClaudeException('The connection closed before the reply finished.');
  }

  Future<http.StreamedResponse> _send(String body) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final request = http.Request('POST', Uri.parse(ClaudeConfig.endpoint))
          ..headers.addAll({
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': ClaudeConfig.apiVersion,
            'anthropic-beta': ClaudeConfig.fallbackBeta,
          })
          ..body = body;
        final response = await _http.send(request);
        if (response.statusCode == 200) return response;

        final text = await response.stream.bytesToString();
        String? type;
        String? message;
        try {
          final json = jsonDecode(text) as Map<String, dynamic>;
          final error = json['error'] as Map<String, dynamic>?;
          type = error?['type'] as String?;
          message = error?['message'] as String?;
        } on FormatException {
          message = null;
        }
        final error = _errorFor(response.statusCode, type, message);
        if (!error.retryable || attempt >= maxRetries) throw error;
        await Future<void>.delayed(
          _retryDelay(response.headers['retry-after'], attempt),
        );
      } on SocketException {
        if (attempt >= maxRetries) {
          throw ClaudeException(
            'Can\'t reach Claude. Check your internet connection.',
            retryable: true,
          );
        }
        await Future<void>.delayed(_retryDelay(null, attempt));
      } on http.ClientException catch (e) {
        if (attempt >= maxRetries) {
          throw ClaudeException(
            'Can\'t reach Claude (${e.message}).',
            retryable: true,
          );
        }
        await Future<void>.delayed(_retryDelay(null, attempt));
      }
    }
  }

  Duration _retryDelay(String? retryAfter, int attempt) {
    final seconds = int.tryParse(retryAfter ?? '');
    if (seconds != null) return Duration(seconds: seconds.clamp(1, 30));
    return Duration(milliseconds: 500 * (1 << attempt));
  }

  ClaudeException _errorFor(int? status, String? type, String? message) {
    final detail = message == null ? '' : ' ($message)';
    return switch ((status, type)) {
      (401, _) || (_, 'authentication_error') => ClaudeException(
        'Your Claude API key was rejected. Check it in Settings.',
        statusCode: status,
      ),
      (403, _) || (_, 'permission_error') => ClaudeException(
        'This API key isn\'t allowed to use ${ClaudeConfig.model}.',
        statusCode: status,
      ),
      (429, _) || (_, 'rate_limit_error') => ClaudeException(
        'Too many requests right now. Wait a moment and try again.',
        statusCode: status,
        retryable: true,
      ),
      (529, _) || (_, 'overloaded_error') => ClaudeException(
        'Claude is busy right now. Try again in a minute.',
        statusCode: status,
        retryable: true,
      ),
      (final int s, _) when s >= 500 => ClaudeException(
        'Claude had a problem on its side. Try again.',
        statusCode: status,
        retryable: true,
      ),
      _ => ClaudeException('The request failed$detail.', statusCode: status),
    };
  }

  void close() => _http.close();
}
