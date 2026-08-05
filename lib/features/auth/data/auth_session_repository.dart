import 'package:cursor/core/config/app_config.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/core/storage/secure_credentials_store.dart';
import 'package:cursor/features/auth/data/auth_remote_source.dart';
import 'package:cursor/features/auth/domain/api_key_info.dart';

class AuthSessionRepository {
  AuthSessionRepository({
    required CursorApiClient apiClient,
    required AuthRemoteSource remoteSource,
    required SecureCredentialsStore credentials,
    required AppConfig config,
  }) : _apiClient = apiClient,
       _remoteSource = remoteSource,
       _credentials = credentials,
       _config = config;

  final CursorApiClient _apiClient;
  final AuthRemoteSource _remoteSource;
  final SecureCredentialsStore _credentials;
  final AppConfig _config;

  ApiKeyInfo? _currentInfo;

  ApiKeyInfo? get currentInfo => _currentInfo;

  Future<ApiKeyInfo?> restore() async {
    final storedKey = _normalize(await _credentials.readApiKey());
    final bootstrapKey = _normalize(_config.bootstrapApiKey);
    final apiKey = storedKey ?? bootstrapKey;

    if (apiKey == null) {
      _clearClientSession();
      return null;
    }

    _apiClient.setApiKey(apiKey);

    try {
      _currentInfo = await _remoteSource.me();
      return _currentInfo;
    } on UnauthorizedException {
      await _credentials.clear();
      _clearClientSession();
      return null;
    }
  }

  Future<ApiKeyInfo> connect(String apiKey) async {
    final trimmed = _normalize(apiKey);
    if (trimmed == null) {
      throw ArgumentError.value(apiKey, 'apiKey', 'API key must not be empty');
    }

    _apiClient.setApiKey(trimmed);

    try {
      final info = await _remoteSource.me();
      await _credentials.saveApiKey(trimmed);
      _currentInfo = info;
      return info;
    } on UnauthorizedException {
      _clearClientSession();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _credentials.clear();
    _clearClientSession();
  }

  String? _normalize(String? apiKey) {
    final trimmed = apiKey?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _clearClientSession() {
    _apiClient.setApiKey(null);
    _currentInfo = null;
  }
}
