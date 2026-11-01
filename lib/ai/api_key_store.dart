import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  static const _key = 'claude_api_key';

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String value) =>
      _storage.write(key: _key, value: value.trim());

  Future<void> delete() => _storage.delete(key: _key);
}

final apiKeyStoreProvider = Provider<ApiKeyStore>((_) => const ApiKeyStore());

/// The saved API key, or null if none.
final apiKeyProvider = AsyncNotifierProvider<ApiKeyNotifier, String?>(
  ApiKeyNotifier.new,
);

class ApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final key = await ref.read(apiKeyStoreProvider).read();
    return (key == null || key.isEmpty) ? null : key;
  }

  Future<void> save(String key) async {
    await ref.read(apiKeyStoreProvider).write(key);
    state = AsyncData(key.trim());
  }

  Future<void> remove() async {
    await ref.read(apiKeyStoreProvider).delete();
    state = const AsyncData(null);
  }
}

/// Rough check that catches pasting the wrong thing; the API has the final
/// say.
bool looksLikeApiKey(String key) =>
    key.trim().startsWith('sk-ant-') && key.trim().length > 20;
