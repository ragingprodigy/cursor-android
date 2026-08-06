import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/features/thread/domain/agent_usage.dart';
import 'package:cursor/features/usage/data/usage_repository.dart';
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

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  test('loadReport posts Admin spend and filtered usage requests', () async {
    final seenPaths = <String>[];
    final seenBodies = <Object?>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    final apiClient = CursorApiClient(dio)..setApiKey('key');
    dio.httpClientAdapter = _Adapter((options) async {
      seenPaths.add(options.path);
      seenBodies.add(options.data);
      expect(options.headers['Authorization'], startsWith('Basic '));
      if (options.path == '/teams/spend') {
        return ResponseBody.fromString(
          '''
          {
            "teamMemberSpend": [
              {"spendCents": 100.5, "email": "a@example.com"},
              {"overallSpendCents": 25, "email": "b@example.com"}
            ],
            "totalPages": 1,
            "totalMembers": 2
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
          "usageEvents": [
            {
              "chargedCents": 10,
              "tokenUsage": {
                "inputTokens": 7,
                "outputTokens": 8,
                "cacheReadTokens": 1,
                "cacheWriteTokens": 2
              }
            }
          ],
          "totalPages": 1
        }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = UsageRepository(
      apiClient: apiClient,
      database: database,
      loadAgentUsage: (_) async => const AgentUsage(totalTokens: 0, runs: []),
    );

    final report = await repository.loadReport(
      startDate: DateTime.utc(2026, 8, 1),
      endDate: DateTime.utc(2026, 8, 2),
    );

    expect(seenPaths, ['/teams/spend', '/teams/filtered-usage-events']);
    expect(seenBodies.first, {'page': 1, 'pageSize': 100});
    expect(seenBodies.last, {
      'startDate': DateTime.utc(2026, 8, 1).millisecondsSinceEpoch,
      'endDate': DateTime.utc(2026, 8, 2).millisecondsSinceEpoch,
      'page': 1,
      'pageSize': 100,
    });
    expect(report.spend!.totalSpendCents, 125.5);
    expect(report.spend!.userCount, 2);
    expect(report.events!.totalTokens, 18);
    expect(report.events!.chargedCents, 10);
    expect(report.adminUnavailable, isFalse);
  });

  test('loadReport keeps spend when usage events fail', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    final apiClient = CursorApiClient(dio)..setApiKey('key');
    dio.httpClientAdapter = _Adapter((options) async {
      if (options.path == '/teams/spend') {
        return ResponseBody.fromString(
          '{"teamMemberSpend":[{"spendCents":40}],"totalPages":1}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString(
        '{"message":"rate limited"}',
        429,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = UsageRepository(
      apiClient: apiClient,
      database: database,
      loadAgentUsage: (_) async => const AgentUsage(totalTokens: 99, runs: []),
    );

    final report = await repository.loadReport(
      startDate: DateTime.utc(2026, 8, 1),
      endDate: DateTime.utc(2026, 8, 2),
    );

    expect(report.spend!.totalSpendCents, 40);
    expect(report.events, isNull);
    expect(report.adminUnavailable, isFalse);
    expect(report.message, contains('Usage events unavailable'));
    expect(report.fallbackUsage, isNull);
  });

  test('loadReport keeps partial spend pages when later page is rate limited', () async {
    var spendCalls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    final apiClient = CursorApiClient(dio)..setApiKey('key');
    dio.httpClientAdapter = _Adapter((options) async {
      if (options.path == '/teams/spend') {
        spendCalls += 1;
        final body = options.data;
        final page = body is Map ? body['page'] : 1;
        if (page == 2) {
          return ResponseBody.fromString(
            '{"message":"rate limited"}',
            429,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return ResponseBody.fromString(
          '''
          {
            "teamMemberSpend":[{"spendCents":10}],
            "totalPages": 3,
            "page": 1,
            "pageSize": 100
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString(
        '{"usageEvents":[],"totalPages":1}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = UsageRepository(
      apiClient: apiClient,
      database: database,
      loadAgentUsage: (_) async => const AgentUsage(totalTokens: 0, runs: []),
    );

    final report = await repository.loadReport(
      startDate: DateTime.utc(2026, 8, 1),
      endDate: DateTime.utc(2026, 8, 2),
    );

    expect(spendCalls, 2);
    expect(report.spend!.totalSpendCents, 10);
    expect(report.spend!.userCount, 1);
    expect(report.message, contains('rate-limited'));
    expect(report.adminUnavailable, isFalse);
  });

  test(
    'loadReport falls back to cached agent usage when Admin is rejected',
    () async {
      await database.agentsDao.upsertAll([
        AgentsCompanion.insert(
          id: 'bc-1',
          name: 'Agent',
          status: 'completed',
          createdAt: DateTime.utc(2026, 8, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
          json: '{"id":"bc-1","name":"Agent","status":"completed"}',
          cachedAt: DateTime.utc(2026, 8, 1),
        ),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
      final apiClient = CursorApiClient(dio)..setApiKey('key');
      dio.httpClientAdapter = _Adapter((options) async {
        return ResponseBody.fromString(
          '{"message":"Forbidden"}',
          403,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final repository = UsageRepository(
        apiClient: apiClient,
        database: database,
        loadAgentUsage: (agentId) async {
          expect(agentId, 'bc-1');
          return const AgentUsage(totalTokens: 12, runs: []);
        },
      );

      final report = await repository.loadReport(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 2),
      );

      expect(report.adminUnavailable, isTrue);
      expect(report.message, contains('Enterprise Admin API key'));
      expect(report.message, contains('not filtered to the selected date range'));
      expect(report.fallbackUsage!.totalTokens, 12);
      expect(report.fallbackAgentCount, 1);
    },
  );
}
