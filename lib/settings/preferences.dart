import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../ai/assistant_client.dart';
import '../transcript/transcription_service.dart';

/// Things the user tells the app once so they don't have to repeat them,
/// like their name for intros. Stored as `preferences.json` in the app's
/// support folder (nothing secret goes here; the API key is in the
/// keychain).
class Preferences {
  const Preferences({
    this.yourName = '',
    this.brandColor = '',
    this.provider = AiProvider.groq,
    this.onboarded = false,
  });

  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
    yourName: json['yourName'] as String? ?? '',
    brandColor: json['brandColor'] as String? ?? '',
    provider:
        AiProvider.values
            .where((p) => p.name == json['provider'])
            .firstOrNull ??
        AiProvider.groq,
    onboarded: json['onboarded'] as bool? ?? false,
  );

  final String yourName;

  /// "#RRGGBB", or empty for the template's own colours.
  final String brandColor;

  /// Which AI service the assistant uses. Groq's free tier by default.
  final AiProvider provider;

  /// The first-run guide has been seen.
  final bool onboarded;

  Preferences copyWith({
    String? yourName,
    String? brandColor,
    AiProvider? provider,
    bool? onboarded,
  }) => Preferences(
    yourName: yourName ?? this.yourName,
    brandColor: brandColor ?? this.brandColor,
    provider: provider ?? this.provider,
    onboarded: onboarded ?? this.onboarded,
  );

  bool get isEmpty => yourName.isEmpty && brandColor.isEmpty;

  Map<String, dynamic> toJson() => {
    if (yourName.isNotEmpty) 'yourName': yourName,
    if (brandColor.isNotEmpty) 'brandColor': brandColor,
    'provider': provider.name,
    if (onboarded) 'onboarded': true,
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
