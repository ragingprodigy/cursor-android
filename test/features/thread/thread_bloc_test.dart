import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/thread/data/thread_repository.dart';
import 'package:cursor/features/thread/domain/agent_detail.dart';
import 'package:cursor/features/thread/domain/thread_message.dart';
import 'package:cursor/features/thread/presentation/thread_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockThreadRepository extends Mock implements ThreadRepository {}

void main() {
  late ThreadRepository repository;
  late StreamController<ThreadSnapshot> cacheController;
  late Completer<ThreadSnapshot> load;

  final agent = AgentDetail(
    id: 'bc-1',
    name: 'Ship Android app',
    status: 'running',
    url: Uri.parse('https://cursor.com/agents/bc-1'),
    latestRunId: 'run-1',
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 2),
  );
  final cachedMessage = UserMessage(
    id: 'run-cached:user',
    runId: 'run-cached',
    text: 'Cached prompt',
    createdAt: DateTime.utc(2026, 8, 1, 10),
  );
  final remoteMessage = AssistantMessage(
    id: 'run-remote:assistant',
    runId: 'run-remote',
    text: 'Remote result',
    createdAt: DateTime.utc(2026, 8, 1, 11),
  );

  setUp(() {
    repository = _MockThreadRepository();
    cacheController = StreamController<ThreadSnapshot>.broadcast();
    when(() => repository.watchCache('bc-1')).thenAnswer((_) {
      return cacheController.stream;
    });
  });

  tearDown(() async {
    await cacheController.close();
  });

  blocTest<ThreadBloc, ThreadState>(
    'started emits cached thread, then fresh ready thread',
    setUp: () {
      load = Completer<ThreadSnapshot>();
    },
    build: () {
      when(() => repository.load('bc-1')).thenAnswer((_) => load.future);
      return ThreadBloc(repository: repository, agentId: 'bc-1');
    },
    act: (bloc) async {
      bloc.add(const ThreadStarted());
      await Future<void>.delayed(Duration.zero);
      cacheController.add(
        ThreadSnapshot.cached(agent: agent, messages: [cachedMessage]),
      );
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.load('bc-1')).called(1);
      load.complete(
        ThreadSnapshot.fresh(agent: agent, messages: [remoteMessage]),
      );
    },
    wait: const Duration(milliseconds: 10),
    expect: () => [
      const ThreadState.loading('bc-1'),
      ThreadState.cached('bc-1', agent: agent, messages: [cachedMessage]),
      ThreadState.ready('bc-1', agent: agent, messages: [remoteMessage]),
    ],
  );

  blocTest<ThreadBloc, ThreadState>(
    'refresh returns cached messages marked stale and offline',
    build: () {
      when(() => repository.load('bc-1')).thenAnswer((_) async {
        return ThreadSnapshot.stale(
          agent: agent,
          messages: [cachedMessage],
          isOffline: true,
        );
      });
      return ThreadBloc(repository: repository, agentId: 'bc-1');
    },
    act: (bloc) => bloc.add(const ThreadRefreshed()),
    expect: () => [
      ThreadState.cached(
        'bc-1',
        agent: agent,
        messages: [cachedMessage],
        isOffline: true,
        isStale: true,
        message: 'Showing cached thread while offline.',
      ),
    ],
  );

  blocTest<ThreadBloc, ThreadState>(
    'refresh failure preserves visible thread',
    build: () {
      when(
        () => repository.load('bc-1'),
      ).thenThrow(const ApiException('Cursor API request failed'));
      return ThreadBloc(repository: repository, agentId: 'bc-1');
    },
    seed: () =>
        ThreadState.ready('bc-1', agent: agent, messages: [remoteMessage]),
    act: (bloc) => bloc.add(const ThreadRefreshed()),
    expect: () => [
      ThreadState.failure(
        'bc-1',
        'Cursor API request failed',
        agent: agent,
        messages: [remoteMessage],
      ),
    ],
  );
}
