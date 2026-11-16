import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sesión persistente y segura: Keychain (iOS) / EncryptedSharedPreferences-Keystore (Android)
/// en lugar de SharedPreferences en claro.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'icex_atlas.session';
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}

/// Almacenamiento del verificador PKCE del flujo OAuth (también cifrado).
class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) => _storage.read(key: 'icex_atlas.pkce.$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: 'icex_atlas.pkce.$key', value: value);

  @override
  Future<void> removeItem({required String key}) => _storage.delete(key: 'icex_atlas.pkce.$key');
}
