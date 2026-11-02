import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'assistant_client.dart';
import 'claude_client.dart';

/// Asks a vision model what's in a picture, so the assistant (which works
/// in text) knows what you attached: a logo, a photo, its colours.
abstract class ImageDescriber {
  Future<String> describe(Uint8List png);
}

const _prompt =
    'You help a video editing assistant. Describe this picture in 2 or 3 '
    'short sentences: what it is (logo, photo, screenshot, illustration...), '
    'the main subject, any text written in it, and its 2-4 main colours as '
    'hex codes like #1A2B3C. No preamble.';

/// Groq's free vision model, through its OpenAI-compatible API.
class GroqVision implements ImageDescriber {
  GroqVision(
    this.apiKey, {
    this.model = 'qwen/qwen3.8-27b',
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  @override
  Future<String> describe(Uint8List png) async {
    final r = await _http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'max_completion_tokens': 400,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': _prompt},
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/png;base64,${base64Encode(png)}',
                    },
                  },
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (r.statusCode != 200) {
      throw AssistantException(
        'Couldn\'t look at the picture (${r.statusCode}).',
        statusCode: r.statusCode,
      );
    }
    final choice =
        ((jsonDecode(r.body) as Map<String, dynamic>)['choices'] as List).first
            as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;
    return _clean('${message['content'] ?? ''}');
  }
}

/// Claude looks at the picture itself.
class ClaudeVision implements ImageDescriber {
  ClaudeVision(this.apiKey, {required this.model, http.Client? client})
    : _http = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  @override
  Future<String> describe(Uint8List png) async {
    final r = await _http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': ClaudeConfig.apiVersion,
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 400,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image',
                    'source': {
                      'type': 'base64',
                      'media_type': 'image/png',
                      'data': base64Encode(png),
                    },
                  },
                  {'type': 'text', 'text': _prompt},
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (r.statusCode != 200) {
      throw AssistantException(
        'Couldn\'t look at the picture (${r.statusCode}).',
        statusCode: r.statusCode,
      );
    }
    final blocks =
        (jsonDecode(r.body) as Map<String, dynamic>)['content'] as List;
    return _clean(
      blocks
          .cast<Map<String, dynamic>>()
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'])
          .join(' '),
    );
  }
}

/// Some models think out loud in `<think>` tags first; keep only the answer.
String _clean(String text) => text
    .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The picture at [path], shrunk to at most [maxSide] and re-encoded as
/// PNG, plus whether it has see-through pixels (likely a logo cut-out).
Future<({Uint8List png, bool transparent})> prepareImage(
  String path, {
  int maxSide = 1024,
}) async {
  final bytes = await File(path).readAsBytes();
  final probe = await ui.instantiateImageCodec(bytes);
  final first = (await probe.getNextFrame()).image;
  final w = first.width;
  final h = first.height;
  first.dispose();
  final k = maxSide / (w > h ? w : h);
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: k < 1 ? (w * k).round() : null,
    targetHeight: k < 1 ? (h * k).round() : null,
  );
  final image = (await codec.getNextFrame()).image;
  final rgba = await image.toByteData();
  var transparent = false;
  if (rgba != null) {
    for (var i = 3; i < rgba.lengthInBytes; i += 4 * 7) {
      if (rgba.getUint8(i) < 250) {
        transparent = true;
        break;
      }
    }
  }
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return (png: png!.buffer.asUint8List(), transparent: transparent);
}

/// Builds the describer for a service and key. Tests override this.
final imageDescriberFactoryProvider =
    Provider<ImageDescriber Function(AiProvider, String)>(
      (_) =>
          (provider, key) => switch (provider) {
            AiProvider.groq => GroqVision(key),
            AiProvider.claude => ClaudeVision(key, model: provider.model),
          },
    );
