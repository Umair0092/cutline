import 'dart:convert';

import 'package:cutline/ai/edit_tools.dart';
import 'package:cutline/ai/project_summary.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/title_item.dart';
import 'package:cutline/settings/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

/// Stands in for FFmpeg: "renders" an intro instantly.
final renders = <TitleSpec>[];
Future<MediaAsset> fakeRender(
  Project project,
  TitleSpec spec, {
  String? id,
}) async {
  renders.add(spec);
  return MediaAsset(
    id: id ?? 'intro-${renders.length}',
    path: 'assets/intro-${renders.length}.mp4',
    kind: MediaKind.video,
    duration: spec.duration,
    width: 1920,
    height: 1080,
    title: spec,
  );
}

void main() {
  const tools = EditToolbox();
  const prefs = Preferences(yourName: 'Umair Hassan', brandColor: '#00B894');
  const ctx = ToolContext(renderIntro: fakeRender, preferences: prefs);
  setUp(renders.clear);

  test('"add an intro with my name and the title Weekly Rails Tips"', () async {
    final out = await tools.run(
      'add_title',
      {
        'template': 'clean-card',
        'placement': 'before',
        'fields': {'title': 'Weekly Rails Tips', 'subtitle': 'by Umair Hassan'},
      },
      threeClips(),
      context: ctx,
    );
    expect(out.isError, isFalse, reason: out.result);
    final intro = out.project.clips.first;
    expect(out.project.mediaById(intro.mediaId)!.title!.fields, {
      'title': 'Weekly Rails Tips',
      'subtitle': 'by Umair Hassan',
      'accent': '#00B894', // brand colour filled in
    });
    expect(out.project.duration, s(44), reason: '4 s intro + 40 s video');
    expect(out.command!.label, 'Add intro');
  });

  test('a lower third over the video gets the saved name', () async {
    final out = await tools.run(
      'add_title',
      {
        'template': 'lower-third',
        'placement': 'over',
        'start': 3,
        'fields': {'role': 'Rails dev'},
      },
      threeClips(),
      context: ctx,
    );
    final title = out.project.titles.single;
    expect(title.start, s(3));
    expect(title.spec.fields, {
      'role': 'Rails dev',
      'name': 'Umair Hassan',
      'barColor': '#00B894',
    });
    expect(
      renders,
      isEmpty,
      reason: 'nothing to render for titles over the video',
    );
  });

  test('mistakes come back as clear errors', () async {
    Future<String> err(String name, Map<String, dynamic> input) async {
      final out = await tools.run(name, input, threeClips(), context: ctx);
      expect(out.isError, isTrue, reason: '$name $input');
      return out.result;
    }

    expect(
      await err('add_title', {
        'template': 'lower-third',
        'placement': 'before',
      }),
      contains('see-through'),
    );
    expect(
      await err('add_title', {
        'template': 'clean-card',
        'placement': 'over',
        'fields': {'colour': '#fff'},
      }),
      contains('has no field "colour"'),
    );
    expect(
      await err('add_title', {
        'template': 'clean-card',
        'placement': 'over',
        'fields': {'accent': 'green'},
      }),
      contains('#6C5CE7'),
    );
    expect(
      await err('add_title', {
        'template': 'clean-card',
        'placement': 'over',
        'fields': {'font': 'Arial'},
      }),
      contains('Inter'),
    );
    expect(
      await err('add_title', {
        'template': 'clean-card',
        'placement': 'over',
        'duration': 30,
      }),
      contains('between'),
    );
    expect(
      await err('edit_title', {'title_id': 'a', 'clip_id': 'b'}),
      contains('exactly one'),
    );
    expect(await err('edit_title', {'clip_id': 'a'}), contains('not an intro'));
    final noRender = await tools.run('add_title', {
      'template': 'clean-card',
      'placement': 'before',
    }, threeClips());
    expect(noRender.result, contains('can\'t be rendered'));
  });

  test('"make it shorter and use blue": the intro is re-rendered', () async {
    final added = await tools.run(
      'add_title',
      {
        'template': 'clean-card',
        'placement': 'before',
        'fields': {'title': 'Hi'},
      },
      threeClips(),
      context: ctx,
    );
    final clipId = added.project.clips.first.id;
    final edited = await tools.run(
      'edit_title',
      {
        'clip_id': clipId,
        'duration': 2.5,
        'fields': {'accent': '#0984e3'},
      },
      added.project,
      context: ctx,
    );
    expect(edited.isError, isFalse, reason: edited.result);
    final media = edited.project.mediaById(edited.project.clips.first.mediaId)!;
    expect(media.title!.duration, const Duration(milliseconds: 2500));
    expect(media.title!.fields['title'], 'Hi', reason: 'untouched fields stay');
    expect(media.title!.fields['accent'], '#0984E3');
    expect(
      edited.project.clips.first.duration,
      const Duration(milliseconds: 2500),
    );
    expect(renders, hasLength(2));
  });

  test('edit and remove a title over the video', () async {
    var out = await tools.run(
      'add_title',
      {'template': 'lower-third', 'placement': 'over'},
      threeClips(),
      context: ctx,
    );
    final id = out.project.titles.single.id;
    out = await tools.run(
      'edit_title',
      {
        'title_id': id,
        'start': 10,
        'fields': {'role': 'Teacher'},
      },
      out.project,
      context: ctx,
    );
    expect(out.project.titles.single.start, s(10));
    expect(out.project.titles.single.spec.fields['role'], 'Teacher');
    expect(out.project.titles.single.spec.fields['name'], 'Umair Hassan');
    out = await tools.run(
      'remove_title',
      {'title_id': id},
      out.project,
      context: ctx,
    );
    expect(out.project.titles, isEmpty);
  });

  test(
    'the summary shows titles, intros (with all field values) and you',
    () async {
      final out = await tools.run(
        'add_title',
        {'template': 'clean-card', 'placement': 'before'},
        threeClips().copyWith(
          titles: [
            TitleItem(
              id: 't1',
              spec: const TitleSpec(
                templateId: 'lower-third',
                duration: Duration(seconds: 5),
              ),
              start: s(2),
            ),
          ],
        ),
        context: ctx,
      );
      final json = jsonDecode(
        jsonEncode(projectSummary(out.project, preferences: prefs)),
      ) as Map<String, dynamic>;
      expect(json['you'], {'name': 'Umair Hassan', 'brandColor': '#00B894'});
      final intro = ((json['clips'] as List).first as Map)['intro'] as Map;
      expect(intro['template'], 'clean-card');
      expect(
        (intro['fields'] as Map)['title'],
        'My Video',
        reason: 'defaults are shown',
      );
      final title = (json['titles'] as List).single as Map;
      expect(title['id'], 't1');
      expect(title['start'], 6.0, reason: 'shifted by the 4 s intro');
    },
  );
}
