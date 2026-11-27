import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../ai/builtin_keys.dart';

/// Keeps the ElevenLabs key in the system keychain, next to the AI and
/// GIPHY keys.
class ElevenLabsKeyStore {
  const ElevenLabsKeyStore([this._storage = _defaultStorage]);

  final FlutterSecureStorage _storage;
  static const _defaultStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _key = 'elevenlabs_api_key';

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String value) =>
      _storage.write(key: _key, value: value.trim());
  Future<void> delete() => _storage.delete(key: _key);
}

final elevenlabsKeyStoreProvider = Provider<ElevenLabsKeyStore>(
  (_) => const ElevenLabsKeyStore(),
);

final elevenlabsKeyProvider =
    AsyncNotifierProvider<ElevenLabsKeyNotifier, String?>(
      ElevenLabsKeyNotifier.new,
    );

class ElevenLabsKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    try {
      final key = await ref.read(elevenlabsKeyStoreProvider).read();
      if (key != null && key.isNotEmpty) return key;
    } on Object {
      // Fall through to the built-in key.
    }
    return builtinElevenLabsKey.isEmpty ? null : builtinElevenLabsKey;
  }

  Future<void> save(String key) async {
    await ref.read(elevenlabsKeyStoreProvider).write(key);
    state = AsyncData(key.trim());
  }

  Future<void> remove() async {
    await ref.read(elevenlabsKeyStoreProvider).delete();
    state = AsyncData(builtinElevenLabsKey.isEmpty ? null : builtinElevenLabsKey);
  }
}
