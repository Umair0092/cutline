import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'assistant_client.dart';
import 'message_builder.dart';
import 'sse.dart';

/// Groq's free tier, through its OpenAI-compatible chat API.
///
/// The app keeps the conversation in the Messages API format (content
/// blocks, tool_use, tool_result). This client translates it to OpenAI chat
/// messages on the way out, and turns the streamed reply back into the same
/// events [MessageBuilder] understands, so the rest of the assistant doesn't
/// know which service answered.
class GroqClient implements AssistantClient {
  GroqClient({
    required this.apiKey,
    this.model = 'openai/gpt-oss-120b',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  static const endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const maxRetries = 2;

  final String apiKey;
  final String model;
  final http.Client _http;

  @override
  Stream<MessageBuilder> stream({
    required List<Map<String, dynamic>> system,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools = const [],
  }) async* {
    final body = jsonEncode({
      'model': model,
      'stream': true,
      'max_completion_tokens': 8192,
      'messages': toOpenAiMessages(system, messages),
      if (tools.isNotEmpty) ...{
        'tools': toOpenAiTools(tools),
        'tool_choice': 'auto',
      },
    });

    final response = await _send(body);
    final builder = MessageBuilder()
      ..add({
        'type': 'message_start',
        'message': {'model': model},
      });
    final events = _EventMaker();
    await for (final event in parseSse(response.stream)) {
      if (event.data == '[DONE]') break;
      final chunk = jsonDecode(event.data) as Map<String, dynamic>;
      if (chunk['error'] case final Map<String, dynamic> error) {
        throw _errorFor(
          null,
          error['type'] as String?,
          error['message'] as String?,
        );
      }
      for (final e in events.fromChunk(chunk)) {
        builder.add(e);
      }
      yield builder;
    }
    for (final e in events.finish()) {
      builder.add(e);
    }
    yield builder;
  }

  Future<http.StreamedResponse> _send(String body) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final request = http.Request('POST', Uri.parse(endpoint))
          ..headers.addAll({
            'content-type': 'application/json',
            'authorization': 'Bearer $apiKey',
          })
          ..body = body;
        final response = await _http.send(request);
        if (response.statusCode == 200) return response;

        final text = await response.stream.bytesToString();
        String? type;
        String? message;
        try {
          final error =
              (jsonDecode(text) as Map<String, dynamic>)['error']
                  as Map<String, dynamic>?;
          type = (error?['code'] ?? error?['type']) as String?;
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
          throw AssistantException(
            'Can\'t reach Groq. Check your internet connection.',
            retryable: true,
          );
        }
        await Future<void>.delayed(_retryDelay(null, attempt));
      } on http.ClientException catch (e) {
        if (attempt >= maxRetries) {
          throw AssistantException(
            'Can\'t reach Groq (${e.message}).',
            retryable: true,
          );
        }
        await Future<void>.delayed(_retryDelay(null, attempt));
      }
    }
  }

  Duration _retryDelay(String? retryAfter, int attempt) {
    final seconds = double.tryParse(retryAfter ?? '');
    if (seconds != null) {
      return Duration(milliseconds: (seconds.clamp(1, 30) * 1000).round());
    }
    return Duration(milliseconds: 500 * (1 << attempt));
  }

  AssistantException _errorFor(int? status, String? type, String? message) {
    final detail = message == null ? '' : ' ($message)';
    return switch ((status, type)) {
      (401, _) || (_, 'invalid_api_key') => AssistantException(
        'Your Groq API key was rejected. Check it in Settings.',
        statusCode: status,
      ),
      (429, _) || (_, 'rate_limit_exceeded') => AssistantException(
        'Groq\'s free limit was reached for now. Wait a minute and try again.',
        statusCode: status,
        retryable: true,
      ),
      // The model wrote a tool call the API couldn't parse; a retry
      // usually works.
      (_, 'tool_use_failed') => AssistantException(
        'The model sent a broken edit. Please try again.',
        statusCode: status,
        retryable: true,
      ),
      (final int s, _) when s >= 500 => AssistantException(
        'Groq had a problem on its side. Try again.',
        statusCode: status,
        retryable: true,
      ),
      _ => AssistantException('The request failed$detail.', statusCode: status),
    };
  }

  @override
  void close() => _http.close();
}

/// Messages API conversation → OpenAI chat messages.
List<Map<String, dynamic>> toOpenAiMessages(
  List<Map<String, dynamic>> system,
  List<Map<String, dynamic>> messages,
) {
  String textOf(Iterable<dynamic> blocks) => [
    for (final b in blocks.cast<Map<String, dynamic>>())
      if (b['type'] == 'text') b['text'] as String,
  ].join('\n\n');

  final out = <Map<String, dynamic>>[
    if (system.isNotEmpty) {'role': 'system', 'content': textOf(system)},
  ];
  for (final m in messages) {
    final content = m['content'];
    final blocks = content is String
        ? [
            {'type': 'text', 'text': content},
          ]
        : (content as List<dynamic>).cast<Map<String, dynamic>>();
    if (m['role'] == 'assistant') {
      final calls = [
        for (final b in blocks)
          if (b['type'] == 'tool_use')
            {
              'id': b['id'],
              'type': 'function',
              'function': {
                'name': b['name'],
                'arguments': jsonEncode(b['input'] ?? const {}),
              },
            },
      ];
      final text = textOf(blocks);
      out.add({
        'role': 'assistant',
        'content': text.isEmpty ? null : text,
        if (calls.isNotEmpty) 'tool_calls': calls,
      });
      continue;
    }
    // A user turn: tool results become "tool" messages, text stays user.
    for (final b in blocks) {
      if (b['type'] == 'tool_result') {
        final c = b['content'];
        out.add({
          'role': 'tool',
          'tool_call_id': b['tool_use_id'],
          'content': b['is_error'] == true ? 'Error: $c' : '$c',
        });
      }
    }
    final text = textOf(blocks);
    if (text.isNotEmpty) out.add({'role': 'user', 'content': text});
  }
  return out;
}

/// Messages API tool definitions → OpenAI function tools.
List<Map<String, dynamic>> toOpenAiTools(List<Map<String, dynamic>> tools) => [
  for (final t in tools)
    {
      'type': 'function',
      'function': {
        'name': t['name'],
        'description': t['description'],
        'parameters': t['input_schema'],
      },
    },
];

/// Turns OpenAI stream chunks into Messages API stream events.
class _EventMaker {
  bool _textOpen = false;
  final _toolBlocks = <int, int>{}; // OpenAI tool index → block index
  int _nextBlock = 1; // block 0 is the text
  String? _finish;

  List<Map<String, dynamic>> fromChunk(Map<String, dynamic> chunk) {
    final events = <Map<String, dynamic>>[];
    final choices = chunk['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) return events;
    final choice = choices.first as Map<String, dynamic>;
    final delta = choice['delta'] as Map<String, dynamic>? ?? const {};

    final text = delta['content'];
    if (text is String && text.isNotEmpty) {
      if (!_textOpen) {
        _textOpen = true;
        events.add({
          'type': 'content_block_start',
          'index': 0,
          'content_block': {'type': 'text', 'text': ''},
        });
      }
      events.add({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': text},
      });
    }

    for (final call
        in (delta['tool_calls'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()) {
      final i = call['index'] as int? ?? 0;
      final fn = call['function'] as Map<String, dynamic>? ?? const {};
      var block = _toolBlocks[i];
      if (block == null) {
        block = _toolBlocks[i] = _nextBlock++;
        events.add({
          'type': 'content_block_start',
          'index': block,
          'content_block': {
            'type': 'tool_use',
            'id': call['id'] ?? 'call_$i',
            'name': fn['name'] ?? '',
            'input': <String, dynamic>{},
          },
        });
      }
      final args = fn['arguments'];
      if (args is String && args.isNotEmpty) {
        events.add({
          'type': 'content_block_delta',
          'index': block,
          'delta': {'type': 'input_json_delta', 'partial_json': args},
        });
      }
    }

    if (choice['finish_reason'] case final String reason) _finish = reason;
    return events;
  }

  List<Map<String, dynamic>> finish() => [
    if (_textOpen) {'type': 'content_block_stop', 'index': 0},
    for (final block in _toolBlocks.values)
      {'type': 'content_block_stop', 'index': block},
    {
      'type': 'message_delta',
      'delta': {
        'stop_reason': switch (_finish) {
          'tool_calls' => 'tool_use',
          'length' => 'max_tokens',
          'content_filter' => 'refusal',
          _ => 'end_turn',
        },
      },
    },
    {'type': 'message_stop'},
  ];
}
