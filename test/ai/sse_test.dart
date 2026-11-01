import 'dart:convert';

import 'package:cutline/ai/sse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses events split across chunks, with CRLF and comments', () async {
    const raw =
        ': keep-alive\r\nevent: ping\r\ndata: {}\r\n\r\n'
        'event: content_block_delta\ndata: {"a":\ndata: 1}\n\n'
        'data: no-name\n\n';
    final bytes = utf8.encode(raw);
    // Feed it 7 bytes at a time to split events and even UTF-8 sequences.
    final chunks = [
      for (var i = 0; i < bytes.length; i += 7)
        bytes.sublist(i, i + 7 > bytes.length ? bytes.length : i + 7),
    ];
    final events = await parseSse(Stream.fromIterable(chunks)).toList();
    expect(
      [for (final e in events) (e.event, e.data)],
      [
        ('ping', '{}'),
        ('content_block_delta', '{"a":\n1}'),
        ('message', 'no-name'),
      ],
    );
  });
}
