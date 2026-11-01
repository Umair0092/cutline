import 'dart:convert';

/// Rebuilds an assistant message from Messages API stream events.
///
/// Every block is kept exactly as the API sent it (thinking blocks with
/// their signatures, fallback markers, tool calls), because the next request
/// must send the conversation back unchanged.
class MessageBuilder {
  final _blocks = <int, Map<String, dynamic>>{};
  final _partialJson = <int, StringBuffer>{};

  String? model;
  String? stopReason;
  Map<String, dynamic>? stopDetails;

  /// Feeds one decoded `data:` payload. Returns true when the message ended.
  bool add(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'message_start':
        final message = event['message'] as Map<String, dynamic>;
        model = message['model'] as String?;
      case 'content_block_start':
        final index = event['index'] as int;
        final block = Map<String, dynamic>.of(
          event['content_block'] as Map<String, dynamic>,
        );
        _blocks[index] = block;
        if (block['type'] == 'tool_use') _partialJson[index] = StringBuffer();
      case 'content_block_delta':
        final index = event['index'] as int;
        final block = _blocks[index];
        if (block == null) return false;
        final delta = event['delta'] as Map<String, dynamic>;
        switch (delta['type']) {
          case 'text_delta':
            block['text'] = '${block['text'] ?? ''}${delta['text']}';
          case 'thinking_delta':
            block['thinking'] =
                '${block['thinking'] ?? ''}${delta['thinking']}';
          case 'signature_delta':
            block['signature'] = delta['signature'];
          case 'input_json_delta':
            _partialJson[index]?.write(delta['partial_json']);
        }
      case 'content_block_stop':
        final index = event['index'] as int;
        final json = _partialJson.remove(index);
        if (json != null) {
          final block = _blocks[index]!;
          final raw = json.toString();
          try {
            block['input'] = raw.isEmpty
                ? <String, dynamic>{}
                : jsonDecode(raw);
          } on FormatException {
            // Kept so the tool loop can answer with an INVALID_JSON error.
            block['input'] = <String, dynamic>{};
            block['_invalidJson'] = raw;
          }
        }
      case 'message_delta':
        final delta = event['delta'] as Map<String, dynamic>;
        stopReason = delta['stop_reason'] as String? ?? stopReason;
        stopDetails = delta['stop_details'] as Map<String, dynamic>?;
      case 'message_stop':
        return true;
    }
    return false;
  }

  List<Map<String, dynamic>> get blocks {
    final keys = _blocks.keys.toList()..sort();
    return [for (final k in keys) _blocks[k]!];
  }

  /// Text so far, for showing while streaming.
  String get text => blocks
      .where((b) => b['type'] == 'text')
      .map((b) => b['text'] as String? ?? '')
      .join();

  /// Blocks to send back in the next request.
  ///
  /// After a mid-output fallback, thinking and tool_use blocks from before
  /// the last fallback marker belong to the model that declined, so they're
  /// dropped. Our private `_invalidJson` field is removed.
  List<Map<String, dynamic>> get historyBlocks {
    final all = blocks;
    final lastFallback = all.lastIndexWhere((b) => b['type'] == 'fallback');
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < all.length; i++) {
      final b = all[i];
      final type = b['type'];
      if (i < lastFallback &&
          (type == 'thinking' ||
              type == 'redacted_thinking' ||
              type == 'tool_use')) {
        continue;
      }
      out.add(Map.of(b)..remove('_invalidJson'));
    }
    return out;
  }
}
