import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/features/agents/data/agents_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
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

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'remote success parses items, upserts cache, and returns agents',
    () async {
      late RequestOptions seenRequest;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
      dio.httpClientAdapter = _Adapter((options) async {
        seenRequest = options;
        return ResponseBody.fromString(
          '''
        {
          "items": [
            {
              "id": "bc-1",
              "name": "Ship Android app",
              "status": "running",
              "url": "https://cursor.com/agents/bc-1",
              "repos": [{"url": "https://github.com/acme/mobile"}],
              "latestRunId": "run-1",
              "createdAt": "2026-08-01T10:00:00.000Z",
              "updatedAt": "2026-08-02T11:30:00.000Z"
            }
          ]
        }
        ''',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final repository = AgentsRepository(
        apiClient: CursorApiClient(dio),
        database: database,
      );

      final result = await repository.refresh();

      expect(seenRequest.path, '/v1/agents');
      expect(seenRequest.queryParameters, {'limit': 50});
      expect(result.isOffline, isFalse);
      expect(result.isStale, isFalse);
      expect(result.agents.single.id, 'bc-1');
      expect(result.agents.single.name, 'Ship Android app');
      expect(result.agents.single.repoUrl, 'https://github.com/acme/mobile');
      expect(result.agents.single.latestRunId, 'run-1');
      expect(
        result.agents.single.updatedAt,
        DateTime.parse('2026-08-02T11:30:00.000Z'),
      );

      final rows = await database.agentsDao.getAll();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'bc-1');
      expect(rows.single.status, 'running');
      expect(
        rows.single.json,
        contains('"repoUrl":"https://github.com/acme/mobile"'),
      );
      expect(rows.single.json, contains('"latestRunId":"run-1"'));
    },
  );

  test('refresh enriches missing repository urls in the cache', () async {
    final seenPaths = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      seenPaths.add(options.path);
      if (options.path == '/v1/agents/bc-1') {
        return ResponseBody.fromString(
          '''
          {
            "agent": {
              "id": "bc-1",
              "name": "Ship Android app",
              "status": "running",
              "repos": [{"url": "https://github.com/acme/mobile"}],
              "createdAt": "2026-08-01T10:00:00.000Z",
              "updatedAt": "2026-08-02T11:30:00.000Z"
            }
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString(
        '''
        {
          "items": [
            {
              "id": "bc-1",
              "name": "Ship Android app",
              "status": "running",
              "createdAt": "2026-08-01T10:00:00.000Z",
              "updatedAt": "2026-08-02T11:30:00.000Z"
            }
          ]
        }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = AgentsRepository(
      apiClient: CursorApiClient(dio),
      database: database,
    );

    await repository.refresh();
    await expectLater(
      repository.watchCached().map((snapshot) {
        return snapshot.agents.single.repoUrl;
      }),
      emits('https://github.com/acme/mobile'),
    );

    expect(seenPaths, contains('/v1/agents/bc-1'));
  });

  test(
    'network failure returns cached agents marked stale and offline',
    () async {
      await database.agentsDao.upsertAll([
        AgentsCompanion.insert(
          id: 'bc-cached',
          name: 'Cached agent',
          status: 'completed',
          url: const Value('https://cursor.com/agents/bc-cached'),
          latestRunId: const Value('run-cached'),
          createdAt: DateTime.utc(2026, 7, 1),
          updatedAt: DateTime.utc(2026, 7, 2),
          json: '{"id":"bc-cached"}',
          cachedAt: DateTime.utc(2026, 7, 3),
        ),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
      dio.httpClientAdapter = _Adapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      final repository = AgentsRepository(
        apiClient: CursorApiClient(dio),
        database: database,
      );

      final result = await repository.refresh();

      expect(result.isOffline, isTrue);
      expect(result.isStale, isTrue);
      expect(result.agents.single.id, 'bc-cached');
    },
  );

  test('watchCached emits local cache updates', () async {
    final repository = AgentsRepository(
      apiClient: CursorApiClient(Dio()),
      database: database,
    );
    final expectation = expectLater(
      repository.watchCached().map(
        (snapshot) => snapshot.agents.map((agent) => agent.id).toList(),
      ),
      emitsThrough(contains('bc-watch')),
    );

    await database.agentsDao.upsertAll([
      AgentsCompanion.insert(
        id: 'bc-watch',
        name: 'Watched agent',
        status: 'idle',
        url: const Value.absent(),
        latestRunId: const Value.absent(),
        createdAt: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 2),
        json: '{"id":"bc-watch"}',
        cachedAt: DateTime.utc(2026, 6, 3),
      ),
    ]);

    await expectation;
  });

  test('malformed list payload fails with ApiException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString(
        '{"items":{}}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = AgentsRepository(
      apiClient: CursorApiClient(dio),
      database: database,
    );

    await expectLater(repository.refresh(), throwsA(isA<ApiException>()));
  });
}
