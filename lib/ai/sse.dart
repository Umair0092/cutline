import 'dart:async';
import 'dart:convert';

/// One server-sent event: `event: <name>` and its joined `data:` lines.
class SseEvent {
  const SseEvent(this.event, this.data);

  final String event;
  final String data;
}

/// Splits a byte stream into server-sent events. Handles events split across
/// network chunks, multi-line data, CRLF line endings and comment lines.
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  var event = '';
  final data = <String>[];
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty || event.isNotEmpty) {
        yield SseEvent(event.isEmpty ? 'message' : event, data.join('\n'));
      }
      event = '';
      data.clear();
    } else if (line.startsWith(':')) {
      continue;
    } else if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
  }
  if (data.isNotEmpty) {
    yield SseEvent(event.isEmpty ? 'message' : event, data.join('\n'));
  }
}
