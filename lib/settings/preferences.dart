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
    this.models = const {},
    this.customEndpoint = '',
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
    models: switch (json['models']) {
      final Map<String, dynamic> m => {
        for (final MapEntry(:key, :value) in m.entries)
          if (value is String && value.isNotEmpty) key: value,
      },
      _ => const {},
    },
    customEndpoint: json['customEndpoint'] as String? ?? '',
  );

  final String yourName;

  /// "#RRGGBB", or empty for the template's own colours.
  final String brandColor;

  /// Which AI service the assistant uses. Groq's free tier by default.
  final AiProvider provider;

  /// The first-run guide has been seen.
  final bool onboarded;

  /// Per-provider model override, by provider name. Empty uses the
  /// provider's default model.
  final Map<String, String> models;

  /// Base URL for the [AiProvider.custom] endpoint.
  final String customEndpoint;

  Preferences copyWith({
    String? yourName,
    String? brandColor,
    AiProvider? provider,
    bool? onboarded,
    Map<String, String>? models,
    String? customEndpoint,
  }) => Preferences(
    yourName: yourName ?? this.yourName,
    brandColor: brandColor ?? this.brandColor,
    provider: provider ?? this.provider,
    onboarded: onboarded ?? this.onboarded,
    models: models ?? this.models,
    customEndpoint: customEndpoint ?? this.customEndpoint,
  );

  /// The model to use for [provider]: the user's override, or the default.
  String modelFor(AiProvider provider) {
    final override = models[provider.name]?.trim() ?? '';
    return override.isNotEmpty ? override : provider.model;
  }

  /// The chat endpoint for [provider]: the custom URL, or the default.
  String endpointFor(AiProvider provider) =>
      provider.needsEndpoint ? customEndpoint.trim() : provider.endpoint;

  /// A copy with [model] set as the override for [provider] (empty clears it).
  Preferences withModel(AiProvider provider, String model) {
    final next = {...models};
    if (model.trim().isEmpty) {
      next.remove(provider.name);
    } else {
      next[provider.name] = model.trim();
    }
    return copyWith(models: next);
  }

  bool get isEmpty => yourName.isEmpty && brandColor.isEmpty;

  Map<String, dynamic> toJson() => {
    if (yourName.isNotEmpty) 'yourName': yourName,
    if (brandColor.isNotEmpty) 'brandColor': brandColor,
    'provider': provider.name,
    if (onboarded) 'onboarded': true,
    if (models.isNotEmpty) 'models': models,
    if (customEndpoint.isNotEmpty) 'customEndpoint': customEndpoint,
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
