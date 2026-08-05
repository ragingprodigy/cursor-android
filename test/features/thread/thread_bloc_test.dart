import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/sse_client.dart';
import 'package:cursor/features/thread/data/follow_up_draft_store.dart';
import 'package:cursor/features/thread/data/thread_repository.dart';
import 'package:cursor/features/thread/domain/agent_detail.dart';
import 'package:cursor/features/thread/domain/agent_run.dart';
import 'package:cursor/features/thread/domain/thread_message.dart';
import 'package:cursor/features/thread/presentation/thread_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockThreadRepository extends Mock implements ThreadRepository {}

class _MockFollowUpDraftStore extends Mock implements FollowUpDraftStore {}

void main() {
  late ThreadRepository repository;
  late FollowUpDraftStore draftStore;
  late StreamController<ThreadSnapshot> cacheController;
  late Completer<ThreadSnapshot> load;

  ThreadBloc buildBloc({String agentId = 'bc-1'}) {
    return ThreadBloc(
      repository: repository,
      draftStore: draftStore,
      agentId: agentId,
    );
  }

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
    draftStore = _MockFollowUpDraftStore();
    cacheController = StreamController<ThreadSnapshot>.broadcast();
    when(() => repository.watchCache('bc-1')).thenAnswer((_) {
      return cacheController.stream;
    });
    when(() => draftStore.load(any())).thenAnswer((_) async => '');
    when(() => draftStore.save(any(), any())).thenAnswer((_) async {});
    when(() => draftStore.clear(any())).thenAnswer((_) async {});
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
      return buildBloc();
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
      return buildBloc();
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
      return buildBloc();
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

  group('disable send while a run is active', () {
    final activeRun = AgentRun(
      id: 'run-active',
      status: 'RUNNING',
      createdAt: DateTime.utc(2026, 8, 5, 12),
    );

    blocTest<ThreadBloc, ThreadState>(
      'marks the latest active run and disables follow-up submission',
      build: () {
        when(() => repository.load('bc-1')).thenAnswer((_) async {
          return ThreadSnapshot.fresh(agent: agent, runs: [activeRun]);
        });
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ThreadRefreshed()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.latestRunId, 'run-active');
        expect(bloc.state.isLatestRunActive, isTrue);
        expect(bloc.state.canSubmitFollowUp, isFalse);
        expect(bloc.state.canCancel, isTrue);
      },
    );

    blocTest<ThreadBloc, ThreadState>(
      'CREATING also counts as active',
      build: () {
        when(() => repository.load('bc-1')).thenAnswer((_) async {
          return ThreadSnapshot.fresh(
            agent: agent,
            runs: [
              AgentRun(
                id: 'run-creating',
                status: 'CREATING',
                createdAt: DateTime.utc(2026, 8, 5, 12),
              ),
            ],
          );
        });
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ThreadRefreshed()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.isLatestRunActive, isTrue);
        expect(bloc.state.canSubmitFollowUp, isFalse);
      },
    );

    blocTest<ThreadBloc, ThreadState>(
      'completed runs re-enable follow-up submission',
      build: () {
        when(() => repository.load('bc-1')).thenAnswer((_) async {
          return ThreadSnapshot.fresh(
            agent: agent,
            runs: [
              AgentRun(
                id: 'run-done',
                status: 'completed',
                resultText: 'Done',
                createdAt: DateTime.utc(2026, 8, 5, 12),
              ),
            ],
          );
        });
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ThreadRefreshed()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.isLatestRunActive, isFalse);
        expect(bloc.state.canSubmitFollowUp, isTrue);
        expect(bloc.state.canCancel, isFalse);
      },
    );
  });

  group('follow-up', () {
    blocTest<ThreadBloc, ThreadState>(
      'ignored while the latest run is active',
      seed: () => ThreadState.ready(
        'bc-1',
        agent: agent,
        messages: const [],
        latestRunId: 'run-active',
        isLatestRunActive: true,
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const ThreadFollowUpSubmitted('Keep going')),
      expect: () => <ThreadState>[],
      verify: (_) {
        verifyNever(() => repository.sendFollowUp(any(), any()));
      },
    );

    blocTest<ThreadBloc, ThreadState>(
      'sends prompt, clears the draft, and refreshes on success',
      seed: () => ThreadState.ready(
        'bc-1',
        agent: agent,
        messages: const [],
        followUpDraft: 'Keep going',
      ),
      build: () {
        when(() => repository.sendFollowUp('bc-1', 'Keep going')).thenAnswer((
          _,
        ) async {
          return AgentRun(
            id: 'run-2',
            status: 'CREATING',
            createdAt: DateTime.utc(2026, 8, 5, 13),
          );
        });
        when(() => repository.load('bc-1')).thenAnswer((_) async {
          return ThreadSnapshot.fresh(
            agent: agent,
            runs: [
              AgentRun(
                id: 'run-2',
                status: 'CREATING',
                createdAt: DateTime.utc(2026, 8, 5, 13),
              ),
            ],
          );
        });
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ThreadFollowUpSubmitted('Keep going')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        verify(() => repository.sendFollowUp('bc-1', 'Keep going')).called(1);
        verify(() => draftStore.clear('bc-1')).called(1);
        expect(bloc.state.followUpDraft, '');
        expect(bloc.state.isSendingFollowUp, isFalse);
        expect(bloc.state.latestRunId, 'run-2');
        expect(bloc.state.isLatestRunActive, isTrue);
      },
    );

    blocTest<ThreadBloc, ThreadState>(
      'keeps the draft and surfaces an error on failure',
      seed: () => ThreadState.ready(
        'bc-1',
        agent: agent,
        messages: const [],
        followUpDraft: 'Keep going',
      ),
      build: () {
        when(
          () => repository.sendFollowUp('bc-1', 'Keep going'),
        ).thenThrow(const NetworkException());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ThreadFollowUpSubmitted('Keep going')),
      expect: () => [
        ThreadState.ready(
          'bc-1',
          agent: agent,
          messages: const [],
          followUpDraft: 'Keep going',
          isSendingFollowUp: true,
        ),
        ThreadState.ready(
          'bc-1',
          agent: agent,
          messages: const [],
          followUpDraft: 'Keep going',
          isSendingFollowUp: false,
          actionMessage: 'Network unavailable',
        ),
      ],
      verify: (_) {
        verifyNever(() => draftStore.clear(any()));
      },
    );

    blocTest<ThreadBloc, ThreadState>(
      'draft changes are persisted to the store',
      build: buildBloc,
      act: (bloc) => bloc.add(const ThreadFollowUpDraftChanged('Ship it')),
      expect: () => [
        const ThreadState.loading('bc-1', followUpDraft: 'Ship it'),
      ],
      verify: (_) {
        verify(() => draftStore.save('bc-1', 'Ship it')).called(1);
      },
    );
  });

  group('cancel', () {
    blocTest<ThreadBloc, ThreadState>(
      'ignored when there is no active run',
      seed: () => ThreadState.ready('bc-1', agent: agent, messages: const []),
      build: buildBloc,
      act: (bloc) => bloc.add(const ThreadCancelRequested()),
      expect: () => <ThreadState>[],
      verify: (_) {
        verifyNever(() => repository.cancelRun(any(), any()));
      },
    );

    blocTest<ThreadBloc, ThreadState>(
      'cancels the active run and refreshes',
      seed: () => ThreadState.ready(
        'bc-1',
        agent: agent,
        messages: const [],
        latestRunId: 'run-active',
        isLatestRunActive: true,
      ),
      build: () {
        when(
          () => repository.cancelRun('bc-1', 'run-active'),
        ).thenAnswer((_) async {});
        when(() => repository.load('bc-1')).thenAnswer((_) async {
          return ThreadSnapshot.fresh(
            agent: agent,
            runs: [
              AgentRun(
                id: 'run-active',
                status: 'cancelled',
                createdAt: DateTime.utc(2026, 8, 5, 12),
              ),
            ],
          );
        });
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ThreadCancelRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        verify(() => repository.cancelRun('bc-1', 'run-active')).called(1);
        expect(bloc.state.isCancelling, isFalse);
        expect(bloc.state.isLatestRunActive, isFalse);
      },
    );

    blocTest<ThreadBloc, ThreadState>(
      'treats a 409 response as non-fatal and refreshes',
      seed: () => ThreadState.ready(
        'bc-1',
        agent: agent,
        messages: const [],
        latestRunId: 'run-active',
        isLatestRunActive: true,
      ),
      build: () {
        when(
          () => repository.cancelRun('bc-1', 'run-active'),
        ).thenThrow(const ApiException('run_not_cancellable', statusCode: 409));
        when(() => repository.load('bc-1')).thenAnswer((_) async {
          return ThreadSnapshot.fresh(
            agent: agent,
            runs: [
              AgentRun(
                id: 'run-active',
                status: 'completed',
                resultText: 'Finished already',
                createdAt: DateTime.utc(2026, 8, 5, 12),
              ),
            ],
          );
        });
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ThreadCancelRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.isCancelling, isFalse);
        expect(
          bloc.state.actionMessage,
          'Run already finished or could not be cancelled.',
        );
        expect(bloc.state.isLatestRunActive, isFalse);
      },
    );
  });

  group('streaming', () {
    late StreamController<SseEvent> sseController;

    final activeRun = AgentRun(
      id: 'run-active',
      status: 'RUNNING',
      createdAt: DateTime.utc(2026, 8, 5, 12),
    );

    setUp(() {
      sseController = StreamController<SseEvent>.broadcast();
      when(
        () => repository.streamRun(
          any(),
          any(),
          lastEventId: any(named: 'lastEventId'),
        ),
      ).thenAnswer((_) => sseController.stream);
    });

    tearDown(() async {
      await sseController.close();
    });

    blocTest<ThreadBloc, ThreadState>(
      'applies assistant deltas and tool_call upserts, then refreshes on done',
      build: () {
        var loadCount = 0;
        when(() => repository.load('bc-1')).thenAnswer((_) async {
          loadCount++;
          if (loadCount == 1) {
            return ThreadSnapshot.fresh(agent: agent, runs: [activeRun]);
          }
          return ThreadSnapshot.fresh(
            agent: agent,
            runs: [
              AgentRun(
                id: 'run-active',
                status: 'completed',
                resultText: 'All done',
                createdAt: activeRun.createdAt,
              ),
            ],
          );
        });
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const ThreadRefreshed());
        await Future<void>.delayed(Duration.zero);
        sseController.add(const SseEvent(event: 'assistant', data: 'Hel'));
        await Future<void>.delayed(Duration.zero);
        sseController.add(const SseEvent(event: 'assistant', data: 'lo'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.liveAssistantText, 'Hello');
        sseController.add(
          const SseEvent(
            event: 'tool_call',
            data: '{"name":"flutter test","status":"running"}',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.liveToolSteps, hasLength(1));
        expect(
          (bloc.state.liveToolSteps.single as ToolStepMessage).label,
          'flutter test',
        );
        expect(
          bloc.state.displayMessages.whereType<AssistantMessage>().last.text,
          'Hello',
        );
        sseController.add(const SseEvent(event: 'done', data: '{}'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      verify: (bloc) {
        verify(
          () => repository.streamRun('bc-1', 'run-active', lastEventId: null),
        ).called(1);
        expect(bloc.state.isLatestRunActive, isFalse);
        expect(bloc.state.liveAssistantText, isNull);
        expect(bloc.state.liveToolSteps, isEmpty);
        expect(
          bloc.state.messages.whereType<AssistantMessage>().last.text,
          'All done',
        );
      },
    );

    blocTest<ThreadBloc, ThreadState>(
      'resumes with Last-Event-ID after a transient disconnect',
      build: () {
        when(() => repository.load('bc-1')).thenAnswer((_) async {
          return ThreadSnapshot.fresh(agent: agent, runs: [activeRun]);
        });
        return ThreadBloc(
          repository: repository,
          draftStore: draftStore,
          agentId: 'bc-1',
          pollInterval: const Duration(milliseconds: 15),
          reconnectDelay: const Duration(milliseconds: 15),
        );
      },
      act: (bloc) async {
        bloc.add(const ThreadRefreshed());
        await Future<void>.delayed(Duration.zero);
        sseController.add(
          const SseEvent(event: 'assistant', data: 'partial', id: '5'),
        );
        await Future<void>.delayed(Duration.zero);
        sseController.addError(const NetworkException());
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (_) {
        verify(
          () => repository.streamRun('bc-1', 'run-active', lastEventId: null),
        ).called(1);
        verify(
          () => repository.streamRun('bc-1', 'run-active', lastEventId: '5'),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    blocTest<ThreadBloc, ThreadState>(
      'falls back to polling GET run after a 410 stream_expired error',
      build: () {
        var loadCount = 0;
        when(() => repository.load('bc-1')).thenAnswer((_) async {
          loadCount++;
          if (loadCount == 1) {
            return ThreadSnapshot.fresh(agent: agent, runs: [activeRun]);
          }
          return ThreadSnapshot.fresh(
            agent: agent,
            runs: [
              AgentRun(
                id: 'run-active',
                status: 'completed',
                createdAt: activeRun.createdAt,
              ),
            ],
          );
        });
        when(() => repository.loadRun('bc-1', 'run-active')).thenAnswer((
          _,
        ) async {
          return AgentRun(
            id: 'run-active',
            status: 'completed',
            createdAt: activeRun.createdAt,
          );
        });
        return ThreadBloc(
          repository: repository,
          draftStore: draftStore,
          agentId: 'bc-1',
          pollInterval: const Duration(milliseconds: 15),
          reconnectDelay: const Duration(milliseconds: 15),
        );
      },
      act: (bloc) async {
        bloc.add(const ThreadRefreshed());
        await Future<void>.delayed(Duration.zero);
        sseController.addError(
          const ApiException('stream expired', statusCode: 410),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (bloc) {
        verify(
          () => repository.loadRun('bc-1', 'run-active'),
        ).called(greaterThanOrEqualTo(1));
        expect(bloc.state.isLatestRunActive, isFalse);
      },
    );
  });
}
