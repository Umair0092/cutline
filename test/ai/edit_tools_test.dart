import 'dart:convert';

import 'package:cutline/ai/edit_tools.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  const tools = EditToolbox();

  test('every tool has a strict object schema and eager streaming', () async {
    for (final t in tools.definitions) {
      final schema = t['input_schema'] as Map<String, dynamic>;
      expect(schema['type'], 'object');
      expect(
        schema['additionalProperties'],
        isFalse,
        reason: t['name'] as String,
      );
      expect(t['eager_input_streaming'], isTrue);
    }
  });

  test(
    'cut_range edits the working project and reports the new state',
    () async {
      final out = await tools.run('cut_range', {
        'start': 0,
        'end': 5,
      }, threeClips());
      expect(out.isError, isFalse);
      expect(out.project.duration, s(35));
      expect(out.command!.label, 'Cut 0:00.00–0:05.00');
      final result = jsonDecode(out.result) as Map<String, dynamic>;
      expect((result['project'] as Map)['duration'], 35.0);
    },
  );

  test('keep_only cuts both sides', () async {
    final out = await tools.run('keep_only', {
      'start': 5,
      'end': 15,
    }, threeClips());
    expect(out.project.duration, s(10));
    expect(out.project.clips.first.sourceStart, s(5));
  });

  test('seek moves the playhead without an edit', () async {
    final out = await tools.run('seek', {'time': 12.5}, threeClips());
    expect(out.command, isNull);
    expect(out.seekTo, s(12.5));
  });

  group('bad input comes back as an error the model can read', () {
    Future<void> expectError(
      String name,
      Map<String, dynamic> input,
      String text,
    ) async {
      final out = await tools.run(name, input, threeClips());
      expect(out.isError, isTrue, reason: '$name $input');
      expect(out.result, contains(text));
      expect(out.project, threeClips(), reason: 'nothing changed');
      expect(out.command, isNull);
    }

    test('wrong types, ranges, extras and unknown tools', () async {
      await expectError('cut_range', {
        'start': '0',
        'end': 5,
      }, 'must be a number');
      await expectError('cut_range', {'start': -1, 'end': 5}, 'between');
      await expectError('cut_range', {
        'start': 0,
        'end': 5,
        'x': 1,
      }, 'Unexpected');
      await expectError('set_clip_volume', {
        'clip_id': 'a',
        'volume': 3,
      }, 'between');
      await expectError('delete_clip', {'clip_id': 'zzz'}, 'no clip');
      await expectError('explode', {}, 'Unknown tool');
      await expectError('cut_range', {
        'start': 50,
        'end': 55,
      }, 'Nothing to cut');
    });

    test('invalid JSON is passed back as INVALID_JSON', () async {
      final out = await tools.run(
        'cut_range',
        {},
        threeClips(),
        invalidJson: '{"start": ',
      );
      expect(out.isError, isTrue);
      expect(jsonDecode(out.result), {'INVALID_JSON': '{"start": '});
    });
  });
}
