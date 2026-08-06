import 'package:cursor/core/config/app_config.dart';
import 'package:cursor/core/db/app_database.dart';
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

  test('signOut clears local cache tables', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    await database.agentsDao.upsertAll([
      AgentsCompanion.insert(
        id: 'bc-cache',
        name: 'Cached agent',
        status: 'completed',
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
        json: '{}',
        cachedAt: DateTime.utc(2026, 8, 1, 1),
      ),
    ]);
    await database.threadSnapshotsDao.upsert(
      ThreadSnapshotsCompanion.insert(
        agentId: 'bc-cache',
        json: '{"runs":[]}',
        cachedAt: DateTime.utc(2026, 8, 1, 1),
      ),
    );
    await database.draftsDao.upsert(
      DraftsCompanion.insert(
        id: 'followup:bc-cache',
        content: 'draft',
        updatedAt: DateTime.utc(2026, 8, 1),
      ),
    );
    await database.runPromptsDao.upsert(
      RunPromptsCompanion.insert(
        agentId: 'bc-cache',
        runId: 'run-1',
        content: 'prompt',
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    );
    await database.runResultsDao.upsert(
      RunResultsCompanion.insert(
        agentId: 'bc-cache',
        runId: 'run-1',
        content: 'result',
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    );
    final credentials = _FakeCredentialsStore('stored-key');
    final repository = AuthSessionRepository(
      apiClient: CursorApiClient(Dio()),
      remoteSource: _FakeAuthRemoteSource(
        () async => const ApiKeyInfo(apiKeyName: 'key'),
      ),
      credentials: credentials,
      config: const AppConfig(apiBaseUrl: 'https://api.cursor.com'),
      clearLocalCache: database.clearLocalCache,
    );

    await repository.signOut();

    expect(credentials.apiKey, isNull);
    expect(await database.agentsDao.getAll(), isEmpty);
    expect(await database.threadSnapshotsDao.getByAgentId('bc-cache'), isNull);
    expect(await database.draftsDao.getAll(), isEmpty);
    expect(await database.runPromptsDao.getByAgentId('bc-cache'), isEmpty);
    expect(await database.runResultsDao.getByAgentId('bc-cache'), isEmpty);
  });
}
