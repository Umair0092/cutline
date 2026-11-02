import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../settings/preferences.dart';
import 'assistant_client.dart';
import 'builtin_keys.dart';

/// Keeps the Claude API key in the system keychain (macOS/iOS Keychain,
/// Windows Credential Manager), never in project files or preferences.
class ApiKeyStore {
  const ApiKeyStore([this._storage = _defaultStorage]);

  final FlutterSecureStorage _storage;

  // The login keychain works without a signing team or Keychain Sharing
  // entitlement; the data-protection keychain needs both.
  static const _defaultStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static String _key(AiProvider provider) => '${provider.name}_api_key';

  Future<String?> read(AiProvider provider) =>
      _storage.read(key: _key(provider));

  Future<void> write(AiProvider provider, String value) =>
      _storage.write(key: _key(provider), value: value.trim());

  Future<void> delete(AiProvider provider) =>
      _storage.delete(key: _key(provider));
}

final apiKeyStoreProvider = Provider<ApiKeyStore>((_) => const ApiKeyStore());

/// The service chosen in Settings.
final aiProviderProvider = FutureProvider<AiProvider>((ref) async {
  try {
    return (await ref.watch(preferencesProvider.future)).provider;
  } on Object {
    return AiProvider.groq;
  }
});

/// The saved API key for the chosen service, or null if none.
final apiKeyProvider = AsyncNotifierProvider<ApiKeyNotifier, String?>(
  ApiKeyNotifier.new,
);

class ApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final provider = await ref.watch(aiProviderProvider.future);
    String? key;
    try {
      key = await ref.read(apiKeyStoreProvider).read(provider);
    } on Object {
      key = null;
    }
    if (key != null && key.isNotEmpty) return key;
    // No saved key: use the one built into this copy, if any.
    if (provider == AiProvider.groq && builtinGroqKey.isNotEmpty) {
      return builtinGroqKey;
    }
    return null;
  }

  /// True when the key in use came with the app, not from Settings.
  bool get usingBuiltIn =>
      builtinGroqKey.isNotEmpty && state.value == builtinGroqKey;

  Future<void> save(String key) async {
    final provider = await ref.read(aiProviderProvider.future);
    await ref.read(apiKeyStoreProvider).write(provider, key);
    state = AsyncData(key.trim());
  }

  Future<void> remove() async {
    final provider = await ref.read(aiProviderProvider.future);
    await ref.read(apiKeyStoreProvider).delete(provider);
    state = AsyncData(
      provider == AiProvider.groq && builtinGroqKey.isNotEmpty
          ? builtinGroqKey
          : null,
    );
  }
}
