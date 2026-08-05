import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/agents/data/agents_repository.dart';
import 'package:cursor/features/agents/domain/agent_summary.dart';
import 'package:cursor/features/agents/presentation/agents_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAgentsRepository extends Mock implements AgentsRepository {}

void main() {
  late AgentsRepository repository;
  late StreamController<AgentsSnapshot> cacheController;
  late Completer<AgentsSnapshot> refresh;

  final cachedAgent = AgentSummary(
    id: 'bc-cached',
    name: 'Cached agent',
    status: 'completed',
    url: Uri.parse('https://cursor.com/agents/bc-cached'),
    latestRunId: 'run-cached',
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 2),
  );

  final remoteAgent = AgentSummary(
    id: 'bc-remote',
    name: 'Remote agent',
    status: 'running',
    url: Uri.parse('https://cursor.com/agents/bc-remote'),
    latestRunId: 'run-remote',
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 2),
  );

  setUp(() {
    repository = _MockAgentsRepository();
    cacheController = StreamController<AgentsSnapshot>.broadcast();
    when(() => repository.watchCached()).thenAnswer((_) {
      return cacheController.stream;
    });
  });

  tearDown(() async {
    await cacheController.close();
  });

  blocTest<AgentsBloc, AgentsState>(
    'started emits cached data, then fresh ready data',
    setUp: () {
      refresh = Completer<AgentsSnapshot>();
    },
    build: () {
      when(() => repository.refresh()).thenAnswer((_) => refresh.future);
      return AgentsBloc(repository);
    },
    act: (bloc) async {
      bloc.add(const AgentsStarted());
      await Future<void>.delayed(Duration.zero);
      cacheController.add(AgentsSnapshot.cached([cachedAgent]));
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.refresh()).called(1);
      refresh.complete(AgentsSnapshot.fresh([remoteAgent]));
    },
    wait: const Duration(milliseconds: 10),
    expect: () => [
      const AgentsState.loading(),
      AgentsState.cached([cachedAgent]),
      AgentsState.ready([remoteAgent]),
    ],
  );

  blocTest<AgentsBloc, AgentsState>(
    'refresh returns cached agents marked stale and offline',
    build: () {
      when(() => repository.refresh()).thenAnswer((_) async {
        return AgentsSnapshot.stale([cachedAgent], isOffline: true);
      });
      return AgentsBloc(repository);
    },
    act: (bloc) => bloc.add(const AgentsRefreshed()),
    expect: () => [
      AgentsState.cached(
        [cachedAgent],
        isOffline: true,
        isStale: true,
        message: 'Showing cached agents while offline.',
      ),
    ],
  );

  blocTest<AgentsBloc, AgentsState>(
    'refresh failure without cache emits failure',
    build: () {
      when(
        () => repository.refresh(),
      ).thenThrow(const ApiException('Cursor API request failed'));
      return AgentsBloc(repository);
    },
    act: (bloc) => bloc.add(const AgentsRefreshed()),
    expect: () => const [AgentsState.failure('Cursor API request failed')],
  );

  blocTest<AgentsBloc, AgentsState>(
    'refresh failure with ready agents preserves list and error message',
    build: () {
      when(
        () => repository.refresh(),
      ).thenThrow(const ApiException('Cursor API request failed'));
      return AgentsBloc(repository);
    },
    seed: () => AgentsState.ready([remoteAgent]),
    act: (bloc) => bloc.add(const AgentsRefreshed()),
    expect: () => [
      AgentsState.failure(
        'Cursor API request failed',
        agents: [remoteAgent],
      ),
    ],
  );
}
