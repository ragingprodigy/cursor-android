import 'package:cursor/core/config/app_config.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/core/storage/secure_credentials_store.dart';
import 'package:cursor/features/auth/data/auth_remote_source.dart';
import 'package:cursor/features/auth/domain/api_key_info.dart';
import 'package:flutter/foundation.dart';

class AuthSessionRepository extends ChangeNotifier {
  AuthSessionRepository({
    required CursorApiClient apiClient,
    required AuthRemoteSource remoteSource,
    required SecureCredentialsStore credentials,
    required AppConfig config,
    Future<void> Function()? clearLocalCache,
  }) : this._(apiClient, remoteSource, credentials, config, clearLocalCache);

  AuthSessionRepository._(
    this._apiClient,
    this._remoteSource,
    this._credentials,
    this._config,
    this._clearLocalCache,
  );

  final CursorApiClient _apiClient;
  final AuthRemoteSource _remoteSource;
  final SecureCredentialsStore _credentials;
  final AppConfig _config;
  final Future<void> Function()? _clearLocalCache;

  ApiKeyInfo? _currentInfo;
  bool _hasSessionKey = false;

  ApiKeyInfo? get currentInfo => _currentInfo;

  bool get isAuthenticated => _hasSessionKey;

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
      final info = await _remoteSource.me();
      _setSession(hasSessionKey: true, info: info);
      return info;
    } on UnauthorizedException {
      await signOut();
      return null;
    } on AppException {
      _setSession(hasSessionKey: true, info: null);
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
      _setSession(hasSessionKey: true, info: info);
      return info;
    } on UnauthorizedException {
      _clearClientSession();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _credentials.clear();
      await _clearLocalCache?.call();
    } finally {
      _clearClientSession();
    }
  }

  String? _normalize(String? apiKey) {
    final trimmed = apiKey?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _clearClientSession() {
    _apiClient.setApiKey(null);
    _setSession(hasSessionKey: false, info: null);
  }

  void _setSession({required bool hasSessionKey, required ApiKeyInfo? info}) {
    if (_hasSessionKey == hasSessionKey && _currentInfo == info) {
      return;
    }

    _hasSessionKey = hasSessionKey;
    _currentInfo = info;
    notifyListeners();
  }
}
