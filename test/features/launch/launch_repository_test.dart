import 'dart:convert';

import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/features/launch/data/catalog_remote_source.dart';
import 'package:cursor/features/launch/data/launch_repository.dart';
import 'package:cursor/features/thread/data/run_prompt_store.dart';
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

  test('createAgent omits model when Default is selected', () async {
    late RequestOptions seenRequest;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      seenRequest = options;
      return ResponseBody.fromString(
        '{"agent":{"id":"bc-created"}}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = LaunchRepository(
      catalogRemoteSource: CatalogRemoteSource(CursorApiClient(dio)),
    );

    final id = await repository.createAgent(
      const LaunchRequest(
        prompt: ' Build the feature ',
        repoUrl: 'https://github.com/acme/app',
        startingRef: 'main',
        modelId: 'default',
      ),
    );

    expect(id, 'bc-created');
    expect(seenRequest.path, '/v1/agents');
    final body = seenRequest.data as Map<String, Object?>;
    expect(body['prompt'], {'text': 'Build the feature'});
    expect(body, isNot(contains('model')));
    expect(body['repos'], [
      {'url': 'https://github.com/acme/app', 'startingRef': 'main'},
    ]);
  });

  test('createAgent saves initial prompt for returned run id', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString(
        '{"agent":{"id":"bc-created"},"run":{"id":"run-created"}}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final repository = LaunchRepository(
      catalogRemoteSource: CatalogRemoteSource(CursorApiClient(dio)),
      runPromptStore: RunPromptStore(database.runPromptsDao),
    );

    final id = await repository.createAgent(
      const LaunchRequest(prompt: ' Ship the app '),
    );

    final prompt = await database.runPromptsDao.getByRunId(
      'bc-created',
      'run-created',
    );
    expect(id, 'bc-created');
    expect(prompt!.content, 'Ship the app');
  });

  test(
    'createAgent saves pending initial prompt when run id is absent',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
      dio.httpClientAdapter = _Adapter((options) async {
        return ResponseBody.fromString(
          '{"agent":{"id":"bc-created"}}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final store = RunPromptStore(database.runPromptsDao);
      final repository = LaunchRepository(
        catalogRemoteSource: CatalogRemoteSource(CursorApiClient(dio)),
        runPromptStore: store,
      );

      await repository.createAgent(
        const LaunchRequest(prompt: 'Build first run prompt'),
      );

      final prompts = await store.loadForAgent('bc-created');
      expect(prompts.pendingInitialPrompt, 'Build first run prompt');
      expect(prompts.byRunId, isEmpty);
    },
  );

  test(
    'loadCatalog reuses cached repositories inside rate-limit window',
    () async {
      var repositoryRequests = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
      dio.httpClientAdapter = _Adapter((options) async {
        if (options.path == '/v1/repositories') {
          repositoryRequests += 1;
          return ResponseBody.fromString(
            jsonEncode({
              'items': [
                {
                  'name': 'acme/app',
                  'url': 'https://github.com/acme/app',
                  'defaultBranch': 'main',
                },
              ],
            }),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return ResponseBody.fromString(
          '{"items":[{"id":"gpt-5.5","name":"GPT-5.5"}]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final repository = LaunchRepository(
        catalogRemoteSource: CatalogRemoteSource(CursorApiClient(dio)),
      );

      final first = await repository.loadCatalog();
      final second = await repository.loadCatalog();

      expect(repositoryRequests, 1);
      expect(first.repositories.single.defaultBranch, 'main');
      expect(second.repositories.single.url, 'https://github.com/acme/app');
      expect(second.models.map((model) => model.id), ['default', 'gpt-5.5']);
    },
  );

  test(
    'loadCatalog returns last cache with message after repository failure',
    () async {
      var failRepositories = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
      dio.httpClientAdapter = _Adapter((options) async {
        if (options.path == '/v1/repositories') {
          if (failRepositories) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
          return ResponseBody.fromString(
            '{"items":[{"name":"acme/app","url":"https://github.com/acme/app"}]}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return ResponseBody.fromString(
          '{"items":[]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final repository = LaunchRepository(
        catalogRemoteSource: CatalogRemoteSource(CursorApiClient(dio)),
      );

      await repository.loadCatalog(forceRefresh: true);
      failRepositories = true;
      final stale = await repository.loadCatalog(forceRefresh: true);

      expect(stale.repositories.single.url, 'https://github.com/acme/app');
      expect(stale.message, contains('Showing cached catalog'));
    },
  );
}
