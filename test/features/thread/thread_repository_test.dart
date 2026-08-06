import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/core/network/sse_client.dart';
import 'package:cursor/features/thread/data/run_prompt_store.dart';
import 'package:cursor/features/thread/data/run_result_store.dart';
import 'package:cursor/features/thread/data/thread_repository.dart';
import 'package:cursor/features/thread/domain/thread_message.dart';
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

  test(
    'load fetches agent and runs, maps messages, and caches snapshot',
    () async {
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
              "url": "https://cursor.com/agents/bc-1",
              "latestRunId": "run-2",
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
        if (options.path == '/v1/agents/bc-1/runs/run-1') {
          return ResponseBody.fromString(
            '''
          {
            "run": {
              "id": "run-1",
              "status": "completed",
              "prompt": {"text": "Build the app"},
              "result": {"text": "Implemented the app"},
              "createdAt": "2026-08-01T10:05:00.000Z"
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
              "id": "run-1",
              "status": "completed",
              "prompt": {"text": "Build the app"},
              "createdAt": "2026-08-01T10:05:00.000Z"
            },
            {
              "id": "run-2",
              "status": "running",
              "promptText": "Keep going",
              "createdAt": "2026-08-01T10:10:00.000Z"
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
      final repository = ThreadRepository(
        apiClient: CursorApiClient(dio),
        database: database,
        sseClient: SseClient(dio),
        runResultStore: RunResultStore(database.runResultsDao),
      );

      final snapshot = await repository.load('bc-1');

      expect(seenPaths, [
        '/v1/agents/bc-1',
        '/v1/agents/bc-1/runs',
        '/v1/agents/bc-1/runs/run-1',
        '/v0/agents/bc-1/conversation',
      ]);
      expect(snapshot.agent!.name, 'Ship Android app');
      expect(snapshot.messages, hasLength(3));
      expect(snapshot.messages.whereType<AssistantMessage>(), hasLength(1));
      expect((snapshot.messages.last as UserMessage).text, 'Keep going');

      final row = await database.threadSnapshotsDao.getByAgentId('bc-1');
      expect(row, isNotNull);
      expect(row!.json, contains('"runs"'));
      final result = await database.runResultsDao.getByRunId('bc-1', 'run-1');
      expect(result!.content, 'Implemented the app');
    },
  );

  test(
    'load returns listed runs when terminal result enrichment is rate limited',
    () async {
      final seenPaths = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
      dio.httpClientAdapter = _Adapter((options) async {
        seenPaths.add(options.path);
        if (options.path == '/v1/agents/bc-1') {
          return ResponseBody.fromString(
            '{"agent":{"id":"bc-1","name":"Agent","status":"completed"}}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        if (options.path == '/v1/agents/bc-1/runs/run-1') {
          return ResponseBody.fromString(
            '{"code":"rate_limited","message":"Slow down."}',
            429,
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
              "id": "run-1",
              "status": "completed",
              "promptText": "Prompt",
              "createdAt": "2026-08-01T10:05:00.000Z"
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
      final repository = ThreadRepository(
        apiClient: CursorApiClient(dio),
        database: database,
        sseClient: SseClient(dio),
        runResultStore: RunResultStore(database.runResultsDao),
      );

      final snapshot = await repository.load('bc-1');

      expect(seenPaths, [
        '/v1/agents/bc-1',
        '/v1/agents/bc-1/runs',
        '/v1/agents/bc-1/runs/run-1',
        '/v0/agents/bc-1/conversation',
      ]);
      expect(snapshot.runs.map((run) => run.id), ['run-1']);
      expect(snapshot.messages.whereType<UserMessage>().single.text, 'Prompt');
      final row = await database.threadSnapshotsDao.getByAgentId('bc-1');
      expect(row, isNotNull);
      expect(row!.json, contains('"run-1"'));
    },
  );

  test(
    'network failure returns cached snapshot marked stale and offline',
    () async {
      await database.threadSnapshotsDao.upsert(
        ThreadSnapshotsCompanion.insert(
          agentId: 'bc-cached',
          json: '''
        {
          "agent": {
            "id": "bc-cached",
            "name": "Cached agent",
            "status": "completed",
            "createdAt": "2026-08-01T10:00:00.000Z",
            "updatedAt": "2026-08-01T10:00:00.000Z"
          },
          "runs": [
            {
              "id": "run-cached",
              "status": "completed",
              "promptText": "Cached prompt",
              "resultText": "Cached result",
              "createdAt": "2026-08-01T10:05:00.000Z"
            }
          ]
        }
        ''',
          cachedAt: DateTime.utc(2026, 8, 1, 11),
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
      dio.httpClientAdapter = _Adapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      final repository = ThreadRepository(
        apiClient: CursorApiClient(dio),
        database: database,
        sseClient: SseClient(dio),
      );

      final snapshot = await repository.load('bc-cached');

      expect(snapshot.isOffline, isTrue);
      expect(snapshot.isStale, isTrue);
      expect(snapshot.agent!.id, 'bc-cached');
      expect(snapshot.messages.whereType<AssistantMessage>(), hasLength(1));
    },
  );

  test('watchCache emits snapshot updates for an agent', () async {
    final dio = Dio();
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
    );
    final expectation = expectLater(
      repository.watchCache('bc-watch').map((snapshot) {
        return snapshot.messages.map((message) => message.id).toList();
      }),
      emitsThrough(contains('run-watch:user')),
    );

    await database.threadSnapshotsDao.upsert(
      ThreadSnapshotsCompanion.insert(
        agentId: 'bc-watch',
        json: '''
        {
          "agent": {
            "id": "bc-watch",
            "name": "Watched agent",
            "status": "running",
            "createdAt": "2026-08-01T10:00:00.000Z",
            "updatedAt": "2026-08-01T10:00:00.000Z"
          },
          "runs": [
            {
              "id": "run-watch",
              "status": "running",
              "promptText": "Watched prompt",
              "createdAt": "2026-08-01T10:05:00.000Z"
            }
          ]
        }
        ''',
        cachedAt: DateTime.utc(2026, 8, 1, 11),
      ),
    );

    await expectation;
  });

  test('sendFollowUp posts prompt body and returns created run', () async {
    RequestOptions? seen;
    Object? seenData;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      seen = options;
      seenData = options.data;
      return ResponseBody.fromString(
        '''
        { "run": { "id": "run-3", "status": "CREATING", "createdAt": "2026-08-05T12:00:00.000Z" } }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
      runPromptStore: RunPromptStore(database.runPromptsDao),
    );

    final run = await repository.sendFollowUp('bc-1', 'Keep going');
    final prompt = await database.runPromptsDao.getByRunId('bc-1', 'run-3');

    expect(seen!.method, 'POST');
    expect(seen!.path, '/v1/agents/bc-1/runs');
    expect(seenData, {
      'prompt': {'text': 'Keep going'},
    });
    expect(run.id, 'run-3');
    expect(run.status, 'CREATING');
    expect(run.isActive, isTrue);
    expect(prompt!.content, 'Keep going');
  });

  test('load merges stored run prompts when API omits prompt text', () async {
    final store = RunPromptStore(database.runPromptsDao);
    await store.savePrompt(
      agentId: 'bc-1',
      runId: 'run-1',
      text: 'Persisted follow-up',
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      if (options.path == '/v1/agents/bc-1') {
        return ResponseBody.fromString(
          '{"agent":{"id":"bc-1","name":"Agent","status":"completed"}}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (options.path == '/v1/agents/bc-1/runs/run-1') {
        return ResponseBody.fromString(
          '''
        {
          "run": {
            "id": "run-1",
            "status": "completed",
            "resultText": "Done",
            "createdAt": "2026-08-01T10:05:00.000Z"
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
              "id": "run-1",
              "status": "completed",
              "createdAt": "2026-08-01T10:05:00.000Z"
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
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
      runPromptStore: store,
      runResultStore: RunResultStore(database.runResultsDao),
    );

    final snapshot = await repository.load('bc-1');

    expect(snapshot.messages.first, isA<UserMessage>());
    expect(
      (snapshot.messages.first as UserMessage).text,
      'Persisted follow-up',
    );
    expect(snapshot.messages.whereType<AssistantMessage>().single.text, 'Done');
  });

  test('cached snapshot reload uses pending initial prompt', () async {
    final store = RunPromptStore(database.runPromptsDao);
    await store.savePendingInitialPrompt(
      agentId: 'bc-cached',
      text: 'Persisted launch prompt',
    );
    await database.threadSnapshotsDao.upsert(
      ThreadSnapshotsCompanion.insert(
        agentId: 'bc-cached',
        json: '''
        {
          "agent": {
            "id": "bc-cached",
            "name": "Cached agent",
            "status": "completed",
            "createdAt": "2026-08-01T10:00:00.000Z",
            "updatedAt": "2026-08-01T10:00:00.000Z"
          },
          "runs": [
            {
              "id": "run-cached",
              "status": "completed",
              "resultText": "Cached result",
              "createdAt": "2026-08-01T10:05:00.000Z"
            }
          ]
        }
        ''',
        cachedAt: DateTime.utc(2026, 8, 1, 11),
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
      runPromptStore: store,
    );

    final snapshot = await repository.load('bc-cached');

    expect(snapshot.isStale, isTrue);
    expect(snapshot.messages.first, isA<UserMessage>());
    expect(
      (snapshot.messages.first as UserMessage).text,
      'Persisted launch prompt',
    );
  });

  test(
    'load merges stored run results when API list omits result text',
    () async {
      final resultStore = RunResultStore(database.runResultsDao);
      await resultStore.saveResult(
        agentId: 'bc-1',
        runId: 'run-1',
        text: 'Persisted result',
      );
      final seenPaths = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
      dio.httpClientAdapter = _Adapter((options) async {
        seenPaths.add(options.path);
        if (options.path == '/v1/agents/bc-1') {
          return ResponseBody.fromString(
            '{"agent":{"id":"bc-1","name":"Agent","status":"completed"}}',
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
              "id": "run-1",
              "status": "completed",
              "promptText": "Prompt",
              "createdAt": "2026-08-01T10:05:00.000Z"
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
      final repository = ThreadRepository(
        apiClient: CursorApiClient(dio),
        database: database,
        sseClient: SseClient(dio),
        runResultStore: resultStore,
      );

      final snapshot = await repository.load('bc-1');

      expect(seenPaths, [
        '/v1/agents/bc-1',
        '/v1/agents/bc-1/runs',
        '/v0/agents/bc-1/conversation',
      ]);
      expect(
        snapshot.messages.whereType<AssistantMessage>().single.text,
        'Persisted result',
      );
    },
  );

  test('load maps conversation user texts onto sorted runs', () async {
    final store = RunPromptStore(database.runPromptsDao);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      if (options.path == '/v1/agents/bc-1') {
        return ResponseBody.fromString(
          '{"agent":{"id":"bc-1","name":"Agent","status":"completed"}}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (options.path == '/v0/agents/bc-1/conversation') {
        return ResponseBody.fromString(
          '''
          {
            "messages": [
              {"id": "msg-1", "type": "user_message", "text": "First prompt"},
              {"id": "msg-2", "type": "assistant_message", "text": "First answer"},
              {"id": "msg-3", "type": "user_message", "text": "Second prompt"}
            ]
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
              "id": "run-2",
              "status": "completed",
              "resultText": "Second answer",
              "createdAt": "2026-08-01T10:10:00.000Z"
            },
            {
              "id": "run-1",
              "status": "completed",
              "resultText": "First answer",
              "createdAt": "2026-08-01T10:05:00.000Z"
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
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
      runPromptStore: store,
    );

    final snapshot = await repository.load('bc-1');
    final prompts = snapshot.messages.whereType<UserMessage>().toList();
    final savedFirst = await database.runPromptsDao.getByRunId('bc-1', 'run-1');
    final savedSecond = await database.runPromptsDao.getByRunId(
      'bc-1',
      'run-2',
    );

    expect(prompts.map((message) => message.text), [
      'First prompt',
      'Second prompt',
    ]);
    expect(savedFirst!.content, 'First prompt');
    expect(savedSecond!.content, 'Second prompt');
  });

  test('load ignores missing conversation endpoint', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      if (options.path == '/v1/agents/bc-1') {
        return ResponseBody.fromString(
          '{"agent":{"id":"bc-1","name":"Agent","status":"completed"}}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (options.path == '/v0/agents/bc-1/conversation') {
        return ResponseBody.fromString(
          '{"message":"Not found"}',
          404,
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
              "id": "run-1",
              "status": "completed",
              "promptText": "Fallback prompt",
              "resultText": "Done",
              "createdAt": "2026-08-01T10:05:00.000Z"
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
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
      runPromptStore: RunPromptStore(database.runPromptsDao),
    );

    final snapshot = await repository.load('bc-1');

    expect(
      snapshot.messages.whereType<UserMessage>().single.text,
      'Fallback prompt',
    );
    expect(snapshot.messages.whereType<AssistantMessage>().single.text, 'Done');
  });

  test('cached snapshot reload merges stored run result', () async {
    final resultStore = RunResultStore(database.runResultsDao);
    await resultStore.saveResult(
      agentId: 'bc-cached',
      runId: 'run-cached',
      text: 'Stored cached result',
    );
    await database.threadSnapshotsDao.upsert(
      ThreadSnapshotsCompanion.insert(
        agentId: 'bc-cached',
        json: '''
        {
          "agent": {
            "id": "bc-cached",
            "name": "Cached agent",
            "status": "completed",
            "createdAt": "2026-08-01T10:00:00.000Z",
            "updatedAt": "2026-08-01T10:00:00.000Z"
          },
          "runs": [
            {
              "id": "run-cached",
              "status": "completed",
              "promptText": "Cached prompt",
              "createdAt": "2026-08-01T10:05:00.000Z"
            }
          ]
        }
        ''',
        cachedAt: DateTime.utc(2026, 8, 1, 11),
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
      runResultStore: resultStore,
    );

    final snapshot = await repository.load('bc-cached');

    expect(snapshot.isStale, isTrue);
    expect(
      snapshot.messages.whereType<AssistantMessage>().single.text,
      'Stored cached result',
    );
  });

  test('cancelRun posts to the cancel endpoint', () async {
    RequestOptions? seen;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      seen = options;
      return ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
    );

    await repository.cancelRun('bc-1', 'run-1');

    expect(seen!.method, 'POST');
    expect(seen!.path, '/v1/agents/bc-1/runs/run-1/cancel');
  });

  test('cancelRun surfaces 409 as ApiException with statusCode', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString(
        '{"message":"run_not_cancellable"}',
        409,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
    );

    expect(
      () => repository.cancelRun('bc-1', 'run-1'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
  });

  test('loadRun fetches a single run by id and persists result text', () async {
    RequestOptions? seen;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      seen = options;
      return ResponseBody.fromString(
        '''
        {
          "run": {
            "id": "run-1",
            "status": "completed",
            "result": {"text": "Finished from get run"},
            "createdAt": "2026-08-05T12:00:00.000Z"
          }
        }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
      runResultStore: RunResultStore(database.runResultsDao),
    );

    final run = await repository.loadRun('bc-1', 'run-1');
    final result = await database.runResultsDao.getByRunId('bc-1', 'run-1');

    expect(seen!.path, '/v1/agents/bc-1/runs/run-1');
    expect(run.status, 'completed');
    expect(result!.content, 'Finished from get run');
  });

  test('streamRun delegates to the SSE client with the run path', () async {
    RequestOptions? seen;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      seen = options;
      return ResponseBody.fromString('event: done\ndata: {}\n\n', 200);
    });
    final repository = ThreadRepository(
      apiClient: CursorApiClient(dio),
      database: database,
      sseClient: SseClient(dio),
    );

    final events = await repository
        .streamRun('bc-1', 'run-1', lastEventId: '7')
        .toList();

    expect(seen!.path, '/v1/agents/bc-1/runs/run-1/stream');
    expect(seen!.headers['Last-Event-ID'], '7');
    expect(events.single.event, 'done');
  });
}
