import 'package:bloc_test/bloc_test.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/launch/data/launch_draft_store.dart';
import 'package:cursor/features/launch/data/launch_repository.dart';
import 'package:cursor/features/launch/domain/launch_catalog.dart';
import 'package:cursor/features/launch/presentation/launch_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLaunchRepository extends Mock implements LaunchRepository {}

class _MockLaunchDraftStore extends Mock implements LaunchDraftStore {}

void main() {
  late LaunchRepository repository;
  late LaunchDraftStore draftStore;

  const emptyCatalog = LaunchCatalog(
    repositories: [],
    models: [LaunchModel.defaultModel],
    message: null,
  );

  setUpAll(() {
    registerFallbackValue(const LaunchDraft(prompt: 'fallback'));
    registerFallbackValue(const LaunchRequest(prompt: 'fallback'));
  });

  setUp(() {
    repository = _MockLaunchRepository();
    draftStore = _MockLaunchDraftStore();
    when(() => draftStore.load()).thenAnswer((_) async => LaunchDraft.empty);
    when(() => draftStore.save(any())).thenAnswer((_) async {});
    when(() => draftStore.clear()).thenAnswer((_) async {});
    when(() => repository.loadCatalog()).thenAnswer((_) async => emptyCatalog);
  });

  blocTest<LaunchBloc, LaunchState>(
    'started loads saved draft and catalog',
    build: () {
      when(() => draftStore.load()).thenAnswer((_) async {
        return const LaunchDraft(
          prompt: 'Ship the Android app',
          repoUrl: 'https://github.com/acme/app',
          startingRef: 'main',
          modelId: 'gpt-5.5',
        );
      });
      when(() => repository.loadCatalog()).thenAnswer((_) async {
        return const LaunchCatalog(
          repositories: [
            LaunchRepositoryOption(
              name: 'acme/app',
              url: 'https://github.com/acme/app',
              defaultBranch: 'main',
            ),
          ],
          models: [
            LaunchModel.defaultModel,
            LaunchModel(id: 'gpt-5.5', name: 'GPT-5.5'),
          ],
        );
      });
      return LaunchBloc(repository: repository, draftStore: draftStore);
    },
    act: (bloc) => bloc.add(const LaunchStarted()),
    expect: () => [
      const LaunchState.loading(),
      const LaunchState.ready(
        prompt: 'Ship the Android app',
        selectedRepoUrl: 'https://github.com/acme/app',
        startingRef: 'main',
        selectedModelId: 'gpt-5.5',
        repositories: [
          LaunchRepositoryOption(
            name: 'acme/app',
            url: 'https://github.com/acme/app',
            defaultBranch: 'main',
          ),
        ],
        models: [
          LaunchModel.defaultModel,
          LaunchModel(id: 'gpt-5.5', name: 'GPT-5.5'),
        ],
      ),
    ],
  );

  blocTest<LaunchBloc, LaunchState>(
    'field changes autosave launch draft',
    build: () => LaunchBloc(repository: repository, draftStore: draftStore),
    act: (bloc) async {
      bloc.add(const LaunchPromptChanged('Build offline support'));
      bloc.add(
        const LaunchRepositoryChanged(
          'https://github.com/acme/app',
          startingRef: 'main',
        ),
      );
      bloc.add(const LaunchStartingRefChanged('feature/offline'));
      bloc.add(const LaunchModelChanged('gpt-5.5'));
    },
    verify: (_) {
      verify(
        () =>
            draftStore.save(const LaunchDraft(prompt: 'Build offline support')),
      ).called(1);
      verify(
        () => draftStore.save(
          const LaunchDraft(
            prompt: 'Build offline support',
            repoUrl: 'https://github.com/acme/app',
            startingRef: 'main',
          ),
        ),
      ).called(1);
      verify(
        () => draftStore.save(
          const LaunchDraft(
            prompt: 'Build offline support',
            repoUrl: 'https://github.com/acme/app',
            startingRef: 'feature/offline',
          ),
        ),
      ).called(1);
      verify(
        () => draftStore.save(
          const LaunchDraft(
            prompt: 'Build offline support',
            repoUrl: 'https://github.com/acme/app',
            startingRef: 'feature/offline',
            modelId: 'gpt-5.5',
          ),
        ),
      ).called(1);
    },
  );

  blocTest<LaunchBloc, LaunchState>(
    'submit empty prompt emits validation failure and does not create',
    build: () => LaunchBloc(repository: repository, draftStore: draftStore),
    act: (bloc) => bloc.add(const LaunchSubmitted()),
    expect: () => [
      const LaunchState.ready(
        validationMessage: 'Describe what you want the agent to do.',
      ),
    ],
    verify: (_) {
      verifyNever(() => repository.createAgent(any()));
      verifyNever(() => draftStore.clear());
    },
  );

  blocTest<LaunchBloc, LaunchState>(
    'submit success creates agent, clears draft, and emits created',
    build: () {
      when(() => repository.createAgent(any())).thenAnswer((_) async {
        return 'bc-created';
      });
      return LaunchBloc(repository: repository, draftStore: draftStore);
    },
    seed: () => const LaunchState.ready(
      prompt: 'Ship the launch page',
      selectedRepoUrl: 'https://github.com/acme/app',
      startingRef: 'main',
      selectedModelId: 'gpt-5.5',
    ),
    act: (bloc) => bloc.add(const LaunchSubmitted()),
    expect: () => [
      const LaunchState.submitting(
        prompt: 'Ship the launch page',
        selectedRepoUrl: 'https://github.com/acme/app',
        startingRef: 'main',
        selectedModelId: 'gpt-5.5',
      ),
      const LaunchState.created(
        agentId: 'bc-created',
        prompt: 'Ship the launch page',
        selectedRepoUrl: 'https://github.com/acme/app',
        startingRef: 'main',
        selectedModelId: 'gpt-5.5',
      ),
    ],
    verify: (_) {
      verify(
        () => repository.createAgent(
          const LaunchRequest(
            prompt: 'Ship the launch page',
            repoUrl: 'https://github.com/acme/app',
            startingRef: 'main',
            modelId: 'gpt-5.5',
          ),
        ),
      ).called(1);
      verify(() => draftStore.clear()).called(1);
    },
  );

  blocTest<LaunchBloc, LaunchState>(
    'network failure keeps draft and emits failure message',
    build: () {
      when(
        () => repository.createAgent(any()),
      ).thenThrow(const NetworkException());
      return LaunchBloc(repository: repository, draftStore: draftStore);
    },
    seed: () => const LaunchState.ready(prompt: 'Try again later'),
    act: (bloc) => bloc.add(const LaunchSubmitted()),
    expect: () => [
      const LaunchState.submitting(prompt: 'Try again later'),
      const LaunchState.ready(
        prompt: 'Try again later',
        failureMessage: 'Network unavailable',
      ),
    ],
    verify: (_) {
      verifyNever(() => draftStore.clear());
    },
  );
}
