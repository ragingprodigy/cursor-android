import 'package:cursor/core/config/app_config.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/core/storage/secure_credentials_store.dart';
import 'package:cursor/features/auth/data/auth_remote_source.dart';
import 'package:cursor/features/auth/data/auth_session_repository.dart';
import 'package:cursor/features/auth/domain/api_key_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future? cancelFuture,
  ) {
    return handler(options);
  }
}

class _FakeAuthRemoteSource implements AuthRemoteSource {
  _FakeAuthRemoteSource(this.handler);

  final Future<ApiKeyInfo> Function() handler;

  @override
  Future<ApiKeyInfo> me() => handler();
}

class _FakeCredentialsStore implements SecureCredentialsStore {
  _FakeCredentialsStore(this.apiKey);

  String? apiKey;

  @override
  Future<void> clear() async {
    apiKey = null;
  }

  @override
  Future<String?> readApiKey() async => apiKey;

  @override
  Future<void> saveApiKey(String apiKey) async {
    this.apiKey = apiKey;
  }
}

void main() {
  test(
    'restore preserves stored key and authenticates on network failure',
    () async {
      String? authorization;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
      dio.httpClientAdapter = _Adapter((options) async {
        authorization = options.headers['Authorization'] as String?;
        return ResponseBody.fromString(
          '{}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final credentials = _FakeCredentialsStore('stored-key');
      final apiClient = CursorApiClient(dio);
      final repository = AuthSessionRepository(
        apiClient: apiClient,
        remoteSource: _FakeAuthRemoteSource(
          () => throw const NetworkException(),
        ),
        credentials: credentials,
        config: const AppConfig(apiBaseUrl: 'https://api.cursor.com'),
      );

      final info = await repository.restore();
      await apiClient.get<Map<String, dynamic>>('/probe');

      expect(info, isNull);
      expect(repository.currentInfo, isNull);
      expect(repository.isAuthenticated, isTrue);
      expect(credentials.apiKey, 'stored-key');
      expect(authorization, 'Bearer stored-key');
    },
  );

  test('restore clears stored key and client on unauthorized', () async {
    String? authorization;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      authorization = options.headers['Authorization'] as String?;
      return ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final credentials = _FakeCredentialsStore('bad-key');
    final apiClient = CursorApiClient(dio);
    final repository = AuthSessionRepository(
      apiClient: apiClient,
      remoteSource: _FakeAuthRemoteSource(
        () => throw const UnauthorizedException(),
      ),
      credentials: credentials,
      config: const AppConfig(apiBaseUrl: 'https://api.cursor.com'),
    );

    final info = await repository.restore();
    await apiClient.get<Map<String, dynamic>>('/probe');

    expect(info, isNull);
    expect(repository.isAuthenticated, isFalse);
    expect(credentials.apiKey, isNull);
    expect(authorization, isNull);
  });
}
