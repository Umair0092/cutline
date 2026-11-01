import 'dart:io';

import 'package:cutline/storage/project_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../fixtures.dart';

void main() {
  late Directory tmp;
  const store = ProjectStore();

  setUp(() => tmp = Directory.systemTemp.createTempSync('cutline_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('save then load gives the same project', () async {
    final path = p.join(tmp.path, 'Talk.cutline');
    await store.save(threeClips(), path);
    expect(File(p.join(path, 'project.json')).existsSync(), isTrue);
    expect(Directory(p.join(path, 'assets')).existsSync(), isTrue);
    expect(await store.load(path), threeClips());
  });

  test('save as copies project assets to the new folder', () async {
    final first = p.join(tmp.path, 'A.cutline');
    final second = p.join(tmp.path, 'B.cutline');
    await store.save(threeClips(), first);
    File(p.join(first, 'assets', 'meme.gif')).writeAsStringSync('gif');

    await store.save(threeClips(), second, previousPath: first);
    expect(
      File(p.join(second, 'assets', 'meme.gif')).readAsStringSync(),
      'gif',
    );
  });

  test('clear errors for bad folders', () async {
    final notProject = Directory(p.join(tmp.path, 'Nope.cutline'))
      ..createSync();
    await expectLater(
      () => store.load(notProject.path),
      throwsA(
        isA<ProjectFileException>().having(
          (e) => e.message,
          'message',
          contains('not a Cutline project'),
        ),
      ),
    );

    File(p.join(notProject.path, 'project.json')).writeAsStringSync('{oops');
    await expectLater(
      () => store.load(notProject.path),
      throwsA(
        isA<ProjectFileException>().having(
          (e) => e.message,
          'message',
          contains('damaged'),
        ),
      ),
    );

    File(p.join(notProject.path, 'project.json'))
        .writeAsStringSync('{"schemaVersion": 99}');
    await expectLater(
      () => store.load(notProject.path),
      throwsA(
        isA<ProjectFileException>().having(
          (e) => e.message,
          'message',
          contains('newer version'),
        ),
      ),
    );
  });

  test('resolves project-relative asset paths', () {
    expect(ProjectStore.resolve('/abs/v.mp4', '/p.cutline'), '/abs/v.mp4');
    expect(
      ProjectStore.resolve('assets/m.gif', '/p.cutline'),
      '/p.cutline/assets/m.gif',
    );
  });
}
