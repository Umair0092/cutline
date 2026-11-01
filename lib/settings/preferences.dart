import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../transcript/transcription_service.dart';

/// Things the user tells the app once so they don't have to repeat them,
/// like their name for intros. Stored as `preferences.json` in the app's
/// support folder (nothing secret goes here; the API key is in the
/// keychain).
class Preferences {
  const Preferences({this.yourName = '', this.brandColor = ''});

  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
    yourName: json['yourName'] as String? ?? '',
    brandColor: json['brandColor'] as String? ?? '',
  );

  final String yourName;

  /// "#RRGGBB", or empty for the template's own colours.
  final String brandColor;

  bool get isEmpty => yourName.isEmpty && brandColor.isEmpty;

  Map<String, dynamic> toJson() => {
    if (yourName.isNotEmpty) 'yourName': yourName,
    if (brandColor.isNotEmpty) 'brandColor': brandColor,
  };
}

final preferencesProvider =
    AsyncNotifierProvider<PreferencesNotifier, Preferences>(
      PreferencesNotifier.new,
    );

class PreferencesNotifier extends AsyncNotifier<Preferences> {
  Future<File> _file() async => File(
    p.join(await ref.read(supportDirProvider.future), 'preferences.json'),
  );

  @override
  Future<Preferences> build() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return const Preferences();
      return Preferences.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      );
    } on Object {
      return const Preferences();
    }
  }

  Future<void> save(Preferences prefs) async {
    final f = await _file();
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(prefs.toJson()));
    state = AsyncData(prefs);
  }
}
