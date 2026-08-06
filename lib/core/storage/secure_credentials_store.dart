import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureCredentialsStore {
  SecureCredentialsStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _apiKeyKey = 'cursor_api_key';

  final FlutterSecureStorage _storage;

  Future<void> saveApiKey(String apiKey) {
    return _storage.write(key: _apiKeyKey, value: apiKey);
  }

  Future<String?> readApiKey() {
    return _storage.read(key: _apiKeyKey);
  }

  Future<void> clear() {
    return _storage.delete(key: _apiKeyKey);
  }
}
