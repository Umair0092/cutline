import 'dart:async';
import 'dart:convert';

import 'package:cutline/ai/api_key_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builds an SSE body like the Messages API sends for a text reply.
String sseText(
  String text, {
  String stopReason = 'end_turn',
  List<Map<String, dynamic>> before = const [],
}) {
  final events = <Map<String, dynamic>>[
    {
      'type': 'message_start',
      'message': {'id': 'msg_1', 'model': 'claude-opus-5-5', 'content': []},
    },
    ...before,
    {
      'type': 'content_block_start',
      'index': before.isEmpty ? 0 : 1,
      'content_block': {'type': 'text', 'text': ''},
    },
    for (final word in text.split(' '))
      {
        'type': 'content_block_delta',
        'index': before.isEmpty ? 0 : 1,
        'delta': {'type': 'text_delta', 'text': '$word '},
      },
    {'type': 'content_block_stop', 'index': before.isEmpty ? 0 : 1},
    {
      'type': 'message_delta',
      'delta': {'stop_reason': stopReason},
      'usage': {'output_tokens': 5},
    },
    {'type': 'message_stop'},
  ];
  return sse(events);
}

String sse(List<Map<String, dynamic>> events) =>
    [for (final e in events) 'event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n']
        .join();

/// A thinking block with a signature, as Opus 5.5 streams it.
List<Map<String, dynamic>> thinkingEvents() => [
  {
    'type': 'content_block_start',
    'index': 0,
    'content_block': {'type': 'thinking', 'thinking': ''},
  },
  {
    'type': 'content_block_delta',
    'index': 0,
    'delta': {'type': 'signature_delta', 'signature': 'sig123'},
  },
  {'type': 'content_block_stop', 'index': 0},
];

/// A mock HTTP client that answers each request with the next response and
/// records the requests.
class ScriptedHttp {
  ScriptedHttp(this.responses);

  final List<http.StreamedResponse Function()> responses;
  final requests = <Map<String, dynamic>>[];
  final headers = <Map<String, String>>[];

  http.Client get client => MockClient.streaming((request, body) async {
    final bytes = await body.toBytes();
    requests.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    headers.add(request.headers);
    return responses.removeAt(0)();
  });

  static http.StreamedResponse Function() ok(String sseBody) =>
      () => http.StreamedResponse(
        Stream.value(utf8.encode(sseBody)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );

  static http.StreamedResponse Function() status(
    int code,
    String type, {
    Map<String, String> headers = const {},
  }) =>
      () => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'type': 'error',
              'error': {'type': type, 'message': 'nope'},
            }),
          ),
        ),
        code,
        headers: headers,
      );
}

/// In-memory stand-in for the keychain.
class MemoryKeyStore extends ApiKeyStore {
  MemoryKeyStore([this.value]) : super(const FlutterSecureStorage());

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String v) async => value = v.trim();

  @override
  Future<void> delete() async => value = null;
}
