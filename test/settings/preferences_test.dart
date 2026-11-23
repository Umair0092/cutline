import 'package:cutline/ai/assistant_client.dart';
import 'package:cutline/settings/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('modelFor uses the override, then the provider default', () {
    const prefs = Preferences(models: {'grok': 'grok-custom'});
    expect(prefs.modelFor(AiProvider.grok), 'grok-custom');
    expect(prefs.modelFor(AiProvider.gemini), AiProvider.gemini.model);
  });

  test('endpointFor is the custom URL only for the custom provider', () {
    const prefs = Preferences(customEndpoint: 'https://my.endpoint/v1/chat');
    expect(prefs.endpointFor(AiProvider.custom), 'https://my.endpoint/v1/chat');
    expect(prefs.endpointFor(AiProvider.groq), AiProvider.groq.endpoint);
  });

  test('withModel sets and clears a per-provider override', () {
    const prefs = Preferences();
    final set = prefs.withModel(AiProvider.gemini, ' gemini-x ');
    expect(set.models['gemini'], 'gemini-x'); // trimmed
    final cleared = set.withModel(AiProvider.gemini, '  ');
    expect(cleared.models.containsKey('gemini'), isFalse);
  });

  test('models and customEndpoint survive a JSON round-trip', () {
    const prefs = Preferences(
      provider: AiProvider.custom,
      models: {'custom': 'my-model', 'grok': 'grok-4.7'},
      customEndpoint: 'https://host/v1/chat/completions',
    );
    final back = Preferences.fromJson(prefs.toJson());
    expect(back.provider, AiProvider.custom);
    expect(back.models, {'custom': 'my-model', 'grok': 'grok-4.7'});
    expect(back.customEndpoint, 'https://host/v1/chat/completions');
  });

  test('empty model overrides are dropped from JSON', () {
    const prefs = Preferences(models: {'grok': ''});
    expect(Preferences.fromJson(prefs.toJson()).models.containsKey('grok'),
        isFalse);
  });
}
