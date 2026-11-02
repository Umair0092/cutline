import 'dart:io';
import 'dart:ui';

import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/edit_command.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/title_item.dart';
import 'package:cutline/titles/templates.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  test('every template paints every frame at any size without errors', () {
    for (final template in titleTemplates) {
      for (final size in const [
        Size(1920, 1080),
        Size(1080, 1920),
        Size(320, 180),
      ]) {
        final total = template.defaultDuration.inMilliseconds / 1000;
        for (var t = 0.0; t <= total; t += 0.25) {
          final recorder = PictureRecorder();
          template.paint(
            Canvas(recorder),
            size,
            t,
            total,
            TitleValues(template, const {'title': '', 'name': ''}),
          );
          recorder.endRecording();
        }
      }
    }
  });

  // A missing font silently falls back to a system font, so titles would
  // look different on every computer.
  test('every title font is declared in pubspec.yaml with a real file', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final font in titleFonts) {
      final entry = RegExp('- family: $font\\n\\s+fonts:\\n\\s+- asset: (\\S+)')
          .firstMatch(pubspec);
      expect(entry, isNotNull, reason: font);
      expect(File(entry!.group(1)!).existsSync(), isTrue, reason: font);
    }
  });

  test('templates have unique ids, names and sensible fields', () {
    expect(
      titleTemplates.map((t) => t.id).toSet(),
      hasLength(titleTemplates.length),
    );
    for (final t in titleTemplates) {
      // At most one font; a logo watermark has no text at all.
      expect(
        t.fields.where((f) => f.kind == FieldKind.font).length,
        lessThanOrEqualTo(1),
        reason: t.id,
      );
      for (final f in t.fields.where((f) => f.kind == FieldKind.color)) {
        expect(
          parseHexColor(f.defaultValue),
          isNotNull,
          reason: '${t.id}.${f.key}',
        );
      }
    }
    expect(titleTemplates.where((t) => !t.fullFrame).map((t) => t.id), [
      'lower-third',
      'logo-corner',
    ]);
  });

  test('values fall back to defaults and bad input is safe', () {
    final tpl = templateById('clean-card')!;
    final v = TitleValues(tpl, const {
      'title': 'Weekly Rails Tips',
      'accent': 'nope',
      'font': 'Comic Sans',
    });
    expect(v.text('title'), 'Weekly Rails Tips');
    expect(v.text('subtitle'), 'by Your Name');
    expect(
      v.color('accent'),
      const Color(0xFFFFFFFF),
      reason: 'unparseable colour',
    );
    expect(v.font('font'), 'Inter', reason: 'unknown font');
  });

  test('hex colours', () {
    expect(parseHexColor('#6C5CE7'), const Color(0xFF6C5CE7));
    expect(parseHexColor('806C5CE7'), const Color(0x806C5CE7));
    expect(parseHexColor('#12'), isNull);
    expect(toHex(const Color(0xFF6C5CE7)), '#6C5CE7');
  });

  test('initials for the logo reveal', () {
    expect(LogoReveal.initials('Umair Hassan'), 'UH');
    expect(LogoReveal.initials('  cher '), 'C');
    expect(LogoReveal.initials(''), '');
  });

  group('title commands', () {
    const spec = TitleSpec(
      templateId: 'lower-third',
      fields: {'name': 'Umair'},
      duration: Duration(seconds: 3),
    );
    final title = TitleItem(id: 't', spec: spec, start: s(12));

    test('add, move, edit and delete', () {
      var p = AddTitle(title).apply(threeClips());
      p = UpdateTitle('t', start: s(14)).apply(p);
      expect(p.titles.single.start, s(14));
      p = UpdateTitle(
        't',
        spec: spec.copyWith(fields: {'name': 'Ali'}),
      ).apply(p);
      expect(p.titles.single.spec.fields['name'], 'Ali');
      expect(const RemoveTitle('t').apply(p).titles, isEmpty);
      expect(
        () => const RemoveTitle('x').apply(p),
        throwsA(isA<EditException>()),
      );
    });

    test('cuts shift titles after them and drop titles inside them', () {
      var p = AddTitle(title).apply(threeClips());
      p = RemoveRange(s(0), s(5)).apply(p);
      expect(p.titles.single.start, s(7));
      p = RemoveRange(s(6), s(11)).apply(p);
      expect(p.titles, isEmpty);
    });

    test('replacing a generated intro stretches its clips', () {
      const intro = MediaAsset(
        id: 'm1',
        path: 'assets/intro-new.mp4',
        kind: MediaKind.video,
        duration: Duration(seconds: 6),
        title: spec,
      );
      final p = const ReplaceGeneratedMedia(intro).apply(threeClips());
      expect(p.media.single.path, 'assets/intro-new.mp4');
      expect(
        p.clips.every(
          (c) => c.sourceEnd == s(6) && c.sourceStart == Duration.zero,
        ),
        isTrue,
      );
    });
  });
}
