import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/launch/data/launch_draft_store.dart';
import 'package:cursor/features/launch/data/launch_repository.dart';
import 'package:cursor/features/launch/domain/launch_catalog.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class LaunchEvent extends Equatable {
  const LaunchEvent();

  @override
  List<Object?> get props => const [];
}

class LaunchStarted extends LaunchEvent {
  const LaunchStarted();
}

class LaunchPromptChanged extends LaunchEvent {
  const LaunchPromptChanged(this.prompt);

  final String prompt;

  @override
  List<Object?> get props => [prompt];
}

class LaunchRepositoryChanged extends LaunchEvent {
  const LaunchRepositoryChanged(this.repoUrl, {this.startingRef});

  final String? repoUrl;
  final String? startingRef;

  @override
  List<Object?> get props => [repoUrl, startingRef];
}

class LaunchStartingRefChanged extends LaunchEvent {
  const LaunchStartingRefChanged(this.startingRef);

  final String startingRef;

  @override
  List<Object?> get props => [startingRef];
}

class LaunchModelChanged extends LaunchEvent {
  const LaunchModelChanged(this.modelId);

  final String? modelId;

  @override
  List<Object?> get props => [modelId];
}

class LaunchSubmitted extends LaunchEvent {
  const LaunchSubmitted();
}

enum LaunchStatus { loading, ready, submitting, created }

class LaunchState extends Equatable {
  const LaunchState._({
    required this.status,
    required this.prompt,
    required this.repositories,
    required this.models,
    this.selectedRepoUrl,
    this.startingRef,
    this.selectedModelId,
    this.validationMessage,
    this.failureMessage,
    this.catalogMessage,
    this.createdAgentId,
  });

  const LaunchState.loading()
    : this._(
        status: LaunchStatus.loading,
        prompt: '',
        repositories: const [],
        models: const [LaunchModel.defaultModel],
      );

  const LaunchState.ready({
    String prompt = '',
    String? selectedRepoUrl,
    String? startingRef,
    String? selectedModelId,
    List<LaunchRepositoryOption> repositories = const [],
    List<LaunchModel> models = const [LaunchModel.defaultModel],
    String? validationMessage,
    String? failureMessage,
    String? catalogMessage,
  }) : this._(
         status: LaunchStatus.ready,
         prompt: prompt,
         selectedRepoUrl: selectedRepoUrl,
         startingRef: startingRef,
         selectedModelId: selectedModelId,
         repositories: repositories,
         models: models,
         validationMessage: validationMessage,
         failureMessage: failureMessage,
         catalogMessage: catalogMessage,
       );

  const LaunchState.submitting({
    required String prompt,
    String? selectedRepoUrl,
    String? startingRef,
    String? selectedModelId,
    List<LaunchRepositoryOption> repositories = const [],
    List<LaunchModel> models = const [LaunchModel.defaultModel],
    String? catalogMessage,
  }) : this._(
         status: LaunchStatus.submitting,
         prompt: prompt,
         selectedRepoUrl: selectedRepoUrl,
         startingRef: startingRef,
         selectedModelId: selectedModelId,
         repositories: repositories,
         models: models,
         catalogMessage: catalogMessage,
       );

  const LaunchState.created({
    required String agentId,
    required String prompt,
    String? selectedRepoUrl,
    String? startingRef,
    String? selectedModelId,
    List<LaunchRepositoryOption> repositories = const [],
    List<LaunchModel> models = const [LaunchModel.defaultModel],
    String? catalogMessage,
  }) : this._(
         status: LaunchStatus.created,
         prompt: prompt,
         selectedRepoUrl: selectedRepoUrl,
         startingRef: startingRef,
         selectedModelId: selectedModelId,
         repositories: repositories,
         models: models,
         catalogMessage: catalogMessage,
         createdAgentId: agentId,
       );

  final LaunchStatus status;
  final String prompt;
  final String? selectedRepoUrl;
  final String? startingRef;
  final String? selectedModelId;
  final List<LaunchRepositoryOption> repositories;
  final List<LaunchModel> models;
  final String? validationMessage;
  final String? failureMessage;
  final String? catalogMessage;
  final String? createdAgentId;

  bool get isLoading => status == LaunchStatus.loading;
  bool get isSubmitting => status == LaunchStatus.submitting;
  bool get isCreated => status == LaunchStatus.created;

  LaunchState copyWith({
    LaunchStatus? status,
    String? prompt,
    Object? selectedRepoUrl = _sentinel,
    Object? startingRef = _sentinel,
    Object? selectedModelId = _sentinel,
    List<LaunchRepositoryOption>? repositories,
    List<LaunchModel>? models,
    Object? validationMessage = _sentinel,
    Object? failureMessage = _sentinel,
    Object? catalogMessage = _sentinel,
    Object? createdAgentId = _sentinel,
  }) {
    return LaunchState._(
      status: status ?? this.status,
      prompt: prompt ?? this.prompt,
      selectedRepoUrl: selectedRepoUrl == _sentinel
          ? this.selectedRepoUrl
          : selectedRepoUrl as String?,
      startingRef: startingRef == _sentinel
          ? this.startingRef
          : startingRef as String?,
      selectedModelId: selectedModelId == _sentinel
          ? this.selectedModelId
          : selectedModelId as String?,
      repositories: repositories ?? this.repositories,
      models: models ?? this.models,
      validationMessage: validationMessage == _sentinel
          ? this.validationMessage
          : validationMessage as String?,
      failureMessage: failureMessage == _sentinel
          ? this.failureMessage
          : failureMessage as String?,
      catalogMessage: catalogMessage == _sentinel
          ? this.catalogMessage
          : catalogMessage as String?,
      createdAgentId: createdAgentId == _sentinel
          ? this.createdAgentId
          : createdAgentId as String?,
    );
  }

  LaunchDraft toDraft() {
    return LaunchDraft(
      prompt: prompt,
      repoUrl: selectedRepoUrl,
      startingRef: startingRef,
      modelId: selectedModelId == LaunchModel.defaultModel.id
          ? null
          : selectedModelId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    prompt,
    selectedRepoUrl,
    startingRef,
    selectedModelId,
    repositories,
    models,
    validationMessage,
    failureMessage,
    catalogMessage,
    createdAgentId,
  ];
}

class LaunchBloc extends Bloc<LaunchEvent, LaunchState> {
  LaunchBloc({
    required LaunchRepository repository,
    required LaunchDraftStore draftStore,
  }) : _repository = repository,
       _draftStore = draftStore,
       super(const LaunchState.ready()) {
    on<LaunchStarted>(_onStarted);
    on<LaunchPromptChanged>(_onPromptChanged);
    on<LaunchRepositoryChanged>(_onRepositoryChanged);
    on<LaunchStartingRefChanged>(_onStartingRefChanged);
    on<LaunchModelChanged>(_onModelChanged);
    on<LaunchSubmitted>(_onSubmitted);
  }

  final LaunchRepository _repository;
  final LaunchDraftStore _draftStore;

  Future<void> _onStarted(
    LaunchStarted event,
    Emitter<LaunchState> emit,
  ) async {
    emit(const LaunchState.loading());
    final draft = await _draftStore.load();
    final catalog = await _repository.loadCatalog();
    emit(
      LaunchState.ready(
        prompt: draft.prompt,
        selectedRepoUrl: draft.repoUrl,
        startingRef: draft.startingRef,
        selectedModelId: draft.modelId,
        repositories: catalog.repositories,
        models: catalog.models,
        catalogMessage: catalog.message,
      ),
    );
  }

  Future<void> _onPromptChanged(
    LaunchPromptChanged event,
    Emitter<LaunchState> emit,
  ) async {
    final next = state.copyWith(
      status: LaunchStatus.ready,
      prompt: event.prompt,
      validationMessage: null,
      failureMessage: null,
      createdAgentId: null,
    );
    emit(next);
    await _draftStore.save(next.toDraft());
  }

  Future<void> _onRepositoryChanged(
    LaunchRepositoryChanged event,
    Emitter<LaunchState> emit,
  ) async {
    final next = state.copyWith(
      status: LaunchStatus.ready,
      selectedRepoUrl: _blankToNull(event.repoUrl),
      startingRef: _blankToNull(event.startingRef),
      validationMessage: null,
      failureMessage: null,
      createdAgentId: null,
    );
    emit(next);
    await _draftStore.save(next.toDraft());
  }

  Future<void> _onStartingRefChanged(
    LaunchStartingRefChanged event,
    Emitter<LaunchState> emit,
  ) async {
    final next = state.copyWith(
      status: LaunchStatus.ready,
      startingRef: _blankToNull(event.startingRef),
      validationMessage: null,
      failureMessage: null,
      createdAgentId: null,
    );
    emit(next);
    await _draftStore.save(next.toDraft());
  }

  Future<void> _onModelChanged(
    LaunchModelChanged event,
    Emitter<LaunchState> emit,
  ) async {
    final next = state.copyWith(
      status: LaunchStatus.ready,
      selectedModelId: _blankToNull(event.modelId),
      validationMessage: null,
      failureMessage: null,
      createdAgentId: null,
    );
    emit(next);
    await _draftStore.save(next.toDraft());
  }

  Future<void> _onSubmitted(
    LaunchSubmitted event,
    Emitter<LaunchState> emit,
  ) async {
    final prompt = state.prompt.trim();
    if (prompt.isEmpty) {
      emit(
        state.copyWith(
          status: LaunchStatus.ready,
          validationMessage: 'Describe what you want the agent to do.',
          failureMessage: null,
          createdAgentId: null,
        ),
      );
      return;
    }

    emit(
      LaunchState.submitting(
        prompt: state.prompt,
        selectedRepoUrl: state.selectedRepoUrl,
        startingRef: state.startingRef,
        selectedModelId: state.selectedModelId,
        repositories: state.repositories,
        models: state.models,
        catalogMessage: state.catalogMessage,
      ),
    );

    try {
      final agentId = await _repository.createAgent(
        LaunchRequest(
          prompt: prompt,
          repoUrl: state.selectedRepoUrl,
          startingRef: state.startingRef,
          modelId: state.selectedModelId,
        ),
      );
      await _draftStore.clear();
      emit(
        LaunchState.created(
          agentId: agentId,
          prompt: state.prompt,
          selectedRepoUrl: state.selectedRepoUrl,
          startingRef: state.startingRef,
          selectedModelId: state.selectedModelId,
          repositories: state.repositories,
          models: state.models,
          catalogMessage: state.catalogMessage,
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(
          status: LaunchStatus.ready,
          failureMessage: error.message,
          validationMessage: null,
          createdAgentId: null,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: LaunchStatus.ready,
          failureMessage: 'Unable to create agent.',
          validationMessage: null,
          createdAgentId: null,
        ),
      );
    }
  }
}

const _sentinel = Object();

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
