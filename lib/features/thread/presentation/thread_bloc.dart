import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/sse_client.dart';
import 'package:cursor/features/launch/domain/launch_catalog.dart';
import 'package:cursor/features/models/data/models_repository.dart';
import 'package:cursor/features/thread/data/follow_up_draft_store.dart';
import 'package:cursor/features/thread/data/follow_up_model_store.dart';
import 'package:cursor/features/thread/data/thread_repository.dart';
import 'package:cursor/features/thread/domain/agent_detail.dart';
import 'package:cursor/features/thread/domain/agent_run.dart';
import 'package:cursor/features/thread/domain/agent_usage.dart';
import 'package:cursor/features/thread/domain/thread_message.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ThreadEvent extends Equatable {
  const ThreadEvent();

  @override
  List<Object?> get props => const [];
}

class ThreadStarted extends ThreadEvent {
  const ThreadStarted();
}

class ThreadRefreshed extends ThreadEvent {
  const ThreadRefreshed({this.completer});

  final Completer<void>? completer;
}

class ThreadFollowUpDraftChanged extends ThreadEvent {
  const ThreadFollowUpDraftChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

class ThreadFollowUpModelChanged extends ThreadEvent {
  const ThreadFollowUpModelChanged(this.modelId);

  final String? modelId;

  @override
  List<Object?> get props => [modelId];
}

class ThreadFollowUpSubmitted extends ThreadEvent {
  const ThreadFollowUpSubmitted(this.text, {this.modelId});

  final String text;
  final String? modelId;

  @override
  List<Object?> get props => [text, modelId];
}

class ThreadCancelRequested extends ThreadEvent {
  const ThreadCancelRequested();
}

class _ThreadCacheChanged extends ThreadEvent {
  const _ThreadCacheChanged(this.snapshot);

  final ThreadSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

class _ThreadStreamEvent extends ThreadEvent {
  const _ThreadStreamEvent(this.runId, this.event);

  final String runId;
  final SseEvent event;

  @override
  List<Object?> get props => [runId, event];
}

class _ThreadStreamFailed extends ThreadEvent {
  const _ThreadStreamFailed(this.runId, this.error);

  final String runId;
  final Object? error;

  @override
  List<Object?> get props => [runId, error];
}

class _ThreadPollTick extends ThreadEvent {
  const _ThreadPollTick(this.runId);

  final String runId;

  @override
  List<Object?> get props => [runId];
}

class _ThreadStreamRefreshTick extends ThreadEvent {
  const _ThreadStreamRefreshTick(this.runId);

  final String runId;

  @override
  List<Object?> get props => [runId];
}

class _ThreadStatusFinalize extends ThreadEvent {
  const _ThreadStatusFinalize(this.runId);

  final String runId;

  @override
  List<Object?> get props => [runId];
}

enum ThreadStatus { loading, cached, ready, failure }

const _sentinel = Object();

class ThreadState extends Equatable {
  const ThreadState._({
    required this.agentId,
    required this.status,
    required this.agent,
    required this.messages,
    required this.isOffline,
    required this.isStale,
    this.message,
    this.latestRunId,
    this.isLatestRunActive = false,
    this.followUpDraft = '',
    this.isSendingFollowUp = false,
    this.isCancelling = false,
    this.actionMessage,
    this.liveAssistantText,
    this.liveThinkingText,
    this.liveToolSteps = const [],
    this.models = const [LaunchModel.defaultModel],
    this.selectedModelId,
    this.isLoadingModels = false,
    this.agentUsage,
    this.usageMessage,
  });

  const ThreadState.loading(String agentId, {String followUpDraft = ''})
    : this._(
        agentId: agentId,
        status: ThreadStatus.loading,
        agent: null,
        messages: const [],
        isOffline: false,
        isStale: false,
        followUpDraft: followUpDraft,
      );

  const ThreadState.cached(
    String agentId, {
    AgentDetail? agent,
    List<ThreadMessage> messages = const [],
    bool isOffline = false,
    bool isStale = false,
    String? message,
    String? latestRunId,
    bool isLatestRunActive = false,
    String followUpDraft = '',
    bool isSendingFollowUp = false,
    bool isCancelling = false,
    String? actionMessage,
    String? liveAssistantText,
    String? liveThinkingText,
    List<ThreadMessage> liveToolSteps = const [],
    List<LaunchModel> models = const [LaunchModel.defaultModel],
    String? selectedModelId,
    bool isLoadingModels = false,
    AgentUsage? agentUsage,
    String? usageMessage,
  }) : this._(
         agentId: agentId,
         status: ThreadStatus.cached,
         agent: agent,
         messages: messages,
         isOffline: isOffline,
         isStale: isStale,
         message: message,
         latestRunId: latestRunId,
         isLatestRunActive: isLatestRunActive,
         followUpDraft: followUpDraft,
         isSendingFollowUp: isSendingFollowUp,
         isCancelling: isCancelling,
         actionMessage: actionMessage,
         liveAssistantText: liveAssistantText,
         liveThinkingText: liveThinkingText,
         liveToolSteps: liveToolSteps,
         models: models,
         selectedModelId: selectedModelId,
         isLoadingModels: isLoadingModels,
         agentUsage: agentUsage,
         usageMessage: usageMessage,
       );

  const ThreadState.ready(
    String agentId, {
    required AgentDetail? agent,
    required List<ThreadMessage> messages,
    String? latestRunId,
    bool isLatestRunActive = false,
    String followUpDraft = '',
    bool isSendingFollowUp = false,
    bool isCancelling = false,
    String? actionMessage,
    String? liveAssistantText,
    String? liveThinkingText,
    List<ThreadMessage> liveToolSteps = const [],
    List<LaunchModel> models = const [LaunchModel.defaultModel],
    String? selectedModelId,
    bool isLoadingModels = false,
    AgentUsage? agentUsage,
    String? usageMessage,
  }) : this._(
         agentId: agentId,
         status: ThreadStatus.ready,
         agent: agent,
         messages: messages,
         isOffline: false,
         isStale: false,
         latestRunId: latestRunId,
         isLatestRunActive: isLatestRunActive,
         followUpDraft: followUpDraft,
         isSendingFollowUp: isSendingFollowUp,
         isCancelling: isCancelling,
         actionMessage: actionMessage,
         liveAssistantText: liveAssistantText,
         liveThinkingText: liveThinkingText,
         liveToolSteps: liveToolSteps,
         models: models,
         selectedModelId: selectedModelId,
         isLoadingModels: isLoadingModels,
         agentUsage: agentUsage,
         usageMessage: usageMessage,
       );

  const ThreadState.failure(
    String agentId,
    String message, {
    AgentDetail? agent,
    List<ThreadMessage> messages = const [],
    String? latestRunId,
    bool isLatestRunActive = false,
    String followUpDraft = '',
    String? actionMessage,
    List<LaunchModel> models = const [LaunchModel.defaultModel],
    String? selectedModelId,
    bool isLoadingModels = false,
    AgentUsage? agentUsage,
    String? usageMessage,
  }) : this._(
         agentId: agentId,
         status: ThreadStatus.failure,
         agent: agent,
         messages: messages,
         isOffline: false,
         isStale: false,
         message: message,
         latestRunId: latestRunId,
         isLatestRunActive: isLatestRunActive,
         followUpDraft: followUpDraft,
         actionMessage: actionMessage,
         models: models,
         selectedModelId: selectedModelId,
         isLoadingModels: isLoadingModels,
         agentUsage: agentUsage,
         usageMessage: usageMessage,
       );

  final String agentId;
  final ThreadStatus status;
  final AgentDetail? agent;
  final List<ThreadMessage> messages;
  final bool isOffline;
  final bool isStale;
  final String? message;

  /// The most recently known run id, used to target cancel/stream requests.
  final String? latestRunId;

  /// Whether the latest run is `CREATING` or `RUNNING`.
  final bool isLatestRunActive;
  final String followUpDraft;
  final bool isSendingFollowUp;
  final bool isCancelling;

  /// Non-fatal messaging surfaced from follow-up/cancel actions (e.g. a
  /// `409` cancel response), distinct from the terminal [message] banner.
  final String? actionMessage;

  /// In-progress assistant text streamed for the active run, overlaid on
  /// top of [messages] until the run completes and a refresh supersedes it.
  final String? liveAssistantText;

  /// In-progress thinking text streamed for the active run.
  final String? liveThinkingText;

  /// In-progress tool call steps streamed for the active run.
  final List<ThreadMessage> liveToolSteps;

  final List<LaunchModel> models;
  final String? selectedModelId;
  final bool isLoadingModels;
  final AgentUsage? agentUsage;
  final String? usageMessage;

  bool get isLoading => status == ThreadStatus.loading;

  bool get canSubmitFollowUp =>
      agent != null && !isLatestRunActive && !isSendingFollowUp;

  bool get canCancel =>
      isLatestRunActive && latestRunId != null && !isCancelling;

  /// [messages] plus any in-progress streaming overlay, in display order.
  List<ThreadMessage> get displayMessages {
    final hasLiveText =
        liveAssistantText != null && liveAssistantText!.isNotEmpty;
    final hasLiveThinking =
        liveThinkingText != null && liveThinkingText!.isNotEmpty;
    if (liveToolSteps.isEmpty && !hasLiveText && !hasLiveThinking) {
      return messages;
    }
    final runId = latestRunId ?? agentId;
    return [
      ...messages,
      if (hasLiveThinking)
        ThinkingMessage(
          id: 'live:$runId:thinking',
          runId: runId,
          text: liveThinkingText!,
          createdAt: DateTime.now().toUtc(),
        ),
      ...liveToolSteps,
      if (hasLiveText)
        AssistantMessage(
          id: 'live:$runId:assistant',
          runId: runId,
          text: liveAssistantText!,
          status: 'streaming',
          createdAt: DateTime.now().toUtc(),
        ),
    ];
  }

  ThreadState copyWith({
    ThreadStatus? status,
    List<ThreadMessage>? messages,
    bool? isOffline,
    bool? isStale,
    Object? latestRunId = _sentinel,
    bool? isLatestRunActive,
    String? followUpDraft,
    bool? isSendingFollowUp,
    bool? isCancelling,
    Object? actionMessage = _sentinel,
    Object? liveAssistantText = _sentinel,
    Object? liveThinkingText = _sentinel,
    List<ThreadMessage>? liveToolSteps,
    List<LaunchModel>? models,
    Object? selectedModelId = _sentinel,
    bool? isLoadingModels,
    Object? agentUsage = _sentinel,
    Object? usageMessage = _sentinel,
  }) {
    return ThreadState._(
      agentId: agentId,
      status: status ?? this.status,
      agent: agent,
      messages: messages ?? this.messages,
      isOffline: isOffline ?? this.isOffline,
      isStale: isStale ?? this.isStale,
      message: message,
      latestRunId: latestRunId == _sentinel
          ? this.latestRunId
          : latestRunId as String?,
      isLatestRunActive: isLatestRunActive ?? this.isLatestRunActive,
      followUpDraft: followUpDraft ?? this.followUpDraft,
      isSendingFollowUp: isSendingFollowUp ?? this.isSendingFollowUp,
      isCancelling: isCancelling ?? this.isCancelling,
      actionMessage: actionMessage == _sentinel
          ? this.actionMessage
          : actionMessage as String?,
      liveAssistantText: liveAssistantText == _sentinel
          ? this.liveAssistantText
          : liveAssistantText as String?,
      liveThinkingText: liveThinkingText == _sentinel
          ? this.liveThinkingText
          : liveThinkingText as String?,
      liveToolSteps: liveToolSteps ?? this.liveToolSteps,
      models: models ?? this.models,
      selectedModelId: selectedModelId == _sentinel
          ? this.selectedModelId
          : selectedModelId as String?,
      isLoadingModels: isLoadingModels ?? this.isLoadingModels,
      agentUsage: agentUsage == _sentinel
          ? this.agentUsage
          : agentUsage as AgentUsage?,
      usageMessage: usageMessage == _sentinel
          ? this.usageMessage
          : usageMessage as String?,
    );
  }

  @override
  List<Object?> get props {
    return [
      agentId,
      status,
      agent,
      messages,
      isOffline,
      isStale,
      message,
      latestRunId,
      isLatestRunActive,
      followUpDraft,
      isSendingFollowUp,
      isCancelling,
      actionMessage,
      liveAssistantText,
      liveThinkingText,
      liveToolSteps,
      models,
      selectedModelId,
      isLoadingModels,
      agentUsage,
      usageMessage,
    ];
  }
}

class ThreadBloc extends Bloc<ThreadEvent, ThreadState> {
  factory ThreadBloc({
    required ThreadRepository repository,
    required FollowUpDraftStore draftStore,
    ModelsRepository? modelsRepository,
    FollowUpModelStore? modelStore,
    required String agentId,
    Duration pollInterval = const Duration(seconds: 3),
    Duration reconnectDelay = const Duration(seconds: 2),
    Duration maxReconnectDelay = const Duration(seconds: 60),
    Duration streamRefreshInterval = const Duration(seconds: 20),
    int maxReconnectAttempts = 10,
    int refreshEveryReconnectFailures = 3,
    FutureOr<void> Function()? onUnauthorized,
  }) {
    return ThreadBloc._(
      repository,
      draftStore,
      modelsRepository,
      modelStore,
      agentId,
      pollInterval,
      reconnectDelay,
      maxReconnectDelay,
      streamRefreshInterval,
      maxReconnectAttempts,
      refreshEveryReconnectFailures,
      onUnauthorized,
    );
  }

  ThreadBloc._(
    this._repository,
    this._draftStore,
    this._modelsRepository,
    this._modelStore,
    this._agentId,
    this._pollInterval,
    this._reconnectDelay,
    this._maxReconnectDelay,
    this._streamRefreshInterval,
    this._maxReconnectAttempts,
    this._refreshEveryReconnectFailures,
    this._onUnauthorized,
  ) : super(ThreadState.loading(_agentId)) {
    on<ThreadStarted>(_onStarted);
    on<ThreadRefreshed>(_onRefreshed);
    on<ThreadFollowUpDraftChanged>(_onFollowUpDraftChanged);
    on<ThreadFollowUpModelChanged>(_onFollowUpModelChanged);
    on<ThreadFollowUpSubmitted>(_onFollowUpSubmitted);
    on<ThreadCancelRequested>(_onCancelRequested);
    on<_ThreadCacheChanged>(_onCacheChanged);
    on<_ThreadStreamEvent>(_onStreamEvent);
    on<_ThreadStreamFailed>(_onStreamFailed);
    on<_ThreadPollTick>(_onPollTick);
    on<_ThreadStreamRefreshTick>(_onStreamRefreshTick);
    on<_ThreadStatusFinalize>(_onStatusFinalize);
  }

  final ThreadRepository _repository;
  final FollowUpDraftStore _draftStore;
  final ModelsRepository? _modelsRepository;
  final FollowUpModelStore? _modelStore;
  final String _agentId;
  final Duration _pollInterval;
  final Duration _reconnectDelay;
  final Duration _maxReconnectDelay;
  final Duration _streamRefreshInterval;
  final int _maxReconnectAttempts;
  final int _refreshEveryReconnectFailures;
  final FutureOr<void> Function()? _onUnauthorized;

  StreamSubscription<ThreadSnapshot>? _cacheSubscription;
  StreamSubscription<SseEvent>? _streamSubscription;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  Timer? _streamRefreshTimer;
  Timer? _statusFinalizeTimer;

  AgentDetail? _lastAgent;
  List<ThreadMessage> _lastMessages = const [];
  String? _lastLatestRunId;
  bool _lastIsLatestRunActive = false;

  String _followUpDraft = '';
  String? _selectedModelId;
  List<LaunchModel> _models = const [LaunchModel.defaultModel];
  String? _actionMessage;
  String? _streamingRunId;
  String? _lastEventId;
  int _reconnectAttempts = 0;
  bool _retriedInvalidLastEventId = false;
  bool _streamSuspended = false;
  bool _runResultPersisted = false;
  final StringBuffer _liveAssistantBuffer = StringBuffer();
  final StringBuffer _liveThinkingBuffer = StringBuffer();
  final Map<String, ToolStepMessage> _liveToolStepsById = {};

  Future<void> _onStarted(
    ThreadStarted event,
    Emitter<ThreadState> emit,
  ) async {
    emit(ThreadState.loading(_agentId));
    _followUpDraft = await _draftStore.load(_agentId);
    _selectedModelId = await _loadSelectedModel();
    await _cacheSubscription?.cancel();
    _cacheSubscription = _repository.watchCache(_agentId).listen((snapshot) {
      add(_ThreadCacheChanged(snapshot));
    });
    await _loadModels(emit);
    add(const ThreadRefreshed());
  }

  Future<void> _onRefreshed(
    ThreadRefreshed event,
    Emitter<ThreadState> emit,
  ) async {
    try {
      final snapshot = await _repository.load(_agentId);
      if (isClosed) {
        return;
      }
      _remember(snapshot);
      final reloaded = await _syncStreamForLatestRun(snapshot.latestRun);
      final effective = reloaded ?? snapshot;
      final latestRun = effective.latestRun;
      final latestRunId = latestRun?.id;
      final isLatestRunActive = latestRun?.isActive ?? false;
      final keepLiveOverlay = _shouldKeepLiveOverlay(latestRun);
      final liveAssistantText = keepLiveOverlay ? _liveAssistantText() : null;
      final liveThinkingText = keepLiveOverlay ? _liveThinkingText() : null;
      final liveToolSteps = keepLiveOverlay
          ? _liveToolSteps()
          : const <ThreadMessage>[];
      final isCancelling = _shouldKeepCancelling(latestRun);
      if (effective.isStale) {
        emit(
          ThreadState.cached(
            _agentId,
            agent: effective.agent,
            messages: effective.messages,
            isOffline: effective.isOffline,
            isStale: true,
            message: effective.isOffline
                ? 'Showing cached thread while offline.'
                : 'Showing cached thread.',
            latestRunId: latestRunId,
            isLatestRunActive: isLatestRunActive,
            followUpDraft: _followUpDraft,
            isCancelling: isCancelling,
            actionMessage: _actionMessage,
            liveAssistantText: liveAssistantText,
            liveThinkingText: liveThinkingText,
            liveToolSteps: liveToolSteps,
            models: _models,
            selectedModelId: _selectedModelId,
            agentUsage: effective.usage,
            usageMessage: effective.usageMessage,
          ),
        );
        return;
      }
      emit(
        ThreadState.ready(
          _agentId,
          agent: effective.agent,
          messages: effective.messages,
          latestRunId: latestRunId,
          isLatestRunActive: isLatestRunActive,
          followUpDraft: _followUpDraft,
          isCancelling: isCancelling,
          actionMessage: _actionMessage,
          liveAssistantText: liveAssistantText,
          liveThinkingText: liveThinkingText,
          liveToolSteps: liveToolSteps,
          models: _models,
          selectedModelId: _selectedModelId,
          agentUsage: effective.usage,
          usageMessage: effective.usageMessage,
        ),
      );
    } on AppException catch (error) {
      if (isClosed) {
        return;
      }
      emit(_failurePreservingThread(error.message));
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(_failurePreservingThread('Unable to load thread.'));
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _onFollowUpDraftChanged(
    ThreadFollowUpDraftChanged event,
    Emitter<ThreadState> emit,
  ) async {
    _followUpDraft = event.text;
    emit(_withActionMessage(null, state.copyWith(followUpDraft: event.text)));
    await _draftStore.save(_agentId, event.text);
  }

  Future<void> _onFollowUpModelChanged(
    ThreadFollowUpModelChanged event,
    Emitter<ThreadState> emit,
  ) async {
    _selectedModelId = _blankToNull(event.modelId);
    emit(
      _withActionMessage(
        null,
        state.copyWith(selectedModelId: _selectedModelId),
      ),
    );
    await _modelStore?.save(_agentId, _selectedModelId);
  }

  Future<void> _onFollowUpSubmitted(
    ThreadFollowUpSubmitted event,
    Emitter<ThreadState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty || state.isLatestRunActive || state.isSendingFollowUp) {
      return;
    }

    emit(_withActionMessage(null, state.copyWith(isSendingFollowUp: true)));

    late final AgentRun run;
    try {
      final selectedModelId = _selectedModelIdForSubmit(event.modelId);
      run = selectedModelId == null
          ? await _repository.sendFollowUp(_agentId, text)
          : await _repository.sendFollowUp(
              _agentId,
              text,
              modelId: selectedModelId,
            );
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        emit(
          _withActionMessage(
            'Agent is busy. Refreshing thread status.',
            state.copyWith(isSendingFollowUp: false),
          ),
        );
        add(const ThreadRefreshed());
        return;
      }
      if (_isModelRejected(error)) {
        emit(
          _withActionMessage(
            'Cursor rejected the selected model. Choose Default or another '
            'model, then try again. (${error.message})',
            state.copyWith(isSendingFollowUp: false),
          ),
        );
        return;
      }
      emit(
        _withActionMessage(
          error.message,
          state.copyWith(isSendingFollowUp: false),
        ),
      );
      return;
    } on AppException catch (error) {
      emit(
        _withActionMessage(
          error.message,
          state.copyWith(isSendingFollowUp: false),
        ),
      );
      return;
    } catch (_) {
      emit(
        _withActionMessage(
          'Unable to send follow-up.',
          state.copyWith(isSendingFollowUp: false),
        ),
      );
      return;
    }

    _followUpDraft = '';
    try {
      await _draftStore.clear(_agentId);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to clear follow-up draft after send.',
        name: 'ThreadBloc',
        error: error,
        stackTrace: stackTrace,
      );
    }

    emit(
      state.copyWith(
        isSendingFollowUp: false,
        followUpDraft: '',
        latestRunId: run.id,
        isLatestRunActive: run.isActive,
      ),
    );
    await _syncStreamForLatestRun(run);
    add(const ThreadRefreshed());
  }

  Future<void> _onCancelRequested(
    ThreadCancelRequested event,
    Emitter<ThreadState> emit,
  ) async {
    final runId = state.latestRunId;
    if (runId == null || !state.isLatestRunActive || state.isCancelling) {
      return;
    }

    emit(_withActionMessage(null, state.copyWith(isCancelling: true)));

    try {
      await _repository.cancelRun(_agentId, runId);
      emit(state.copyWith(isCancelling: false));
      add(const ThreadRefreshed());
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        emit(
          _withActionMessage(
            'Run already finished or could not be cancelled.',
            state.copyWith(isCancelling: false),
          ),
        );
        add(const ThreadRefreshed());
        return;
      }
      emit(
        _withActionMessage(error.message, state.copyWith(isCancelling: false)),
      );
    } on AppException catch (error) {
      emit(
        _withActionMessage(error.message, state.copyWith(isCancelling: false)),
      );
    } catch (_) {
      emit(
        _withActionMessage(
          'Unable to cancel the run.',
          state.copyWith(isCancelling: false),
        ),
      );
    }
  }

  /// Remembers [message] so it survives the auto-refresh that typically
  /// follows a follow-up/cancel action, then returns [base] with it applied.
  ThreadState _withActionMessage(String? message, ThreadState base) {
    _actionMessage = message;
    return base.copyWith(actionMessage: message);
  }

  Future<String?> _loadSelectedModel() async {
    try {
      return _blankToNull(await _modelStore?.load(_agentId));
    } catch (error, stackTrace) {
      developer.log(
        'Unable to load follow-up model.',
        name: 'ThreadBloc',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _loadModels(Emitter<ThreadState> emit) async {
    final repository = _modelsRepository;
    if (repository == null) {
      return;
    }
    emit(
      state.copyWith(
        models: _models,
        selectedModelId: _selectedModelId,
        isLoadingModels: true,
      ),
    );
    final catalog = await repository.loadModels();
    if (isClosed) {
      return;
    }
    _models = catalog.models;
    emit(
      _withActionMessage(
        catalog.message,
        state.copyWith(
          models: _models,
          selectedModelId: _selectedModelId,
          isLoadingModels: false,
        ),
      ),
    );
  }

  String? _selectedModelIdForSubmit(String? eventModelId) {
    final selected =
        _blankToNull(eventModelId) ?? _blankToNull(_selectedModelId);
    return selected == LaunchModel.defaultModel.id ? null : selected;
  }

  bool _isModelRejected(ApiException error) {
    if (error.statusCode != 400) {
      return false;
    }
    final message = error.message.toLowerCase();
    // Only treat as model rejection when the API message mentions model.
    // Generic "Bad Request" bodies must not steal the real error copy.
    return message.contains('model');
  }

  Future<void> _onCacheChanged(
    _ThreadCacheChanged event,
    Emitter<ThreadState> emit,
  ) async {
    if (event.snapshot.agent == null && event.snapshot.messages.isEmpty) {
      if (state.status == ThreadStatus.loading) {
        return;
      }
    }

    _remember(event.snapshot);
    final reloaded = await _syncStreamForLatestRun(event.snapshot.latestRun);
    if (isClosed) {
      return;
    }
    final snapshot = reloaded ?? event.snapshot;
    if (reloaded != null) {
      _remember(reloaded);
    }

    final latestRun = snapshot.latestRun;
    final latestRunId = latestRun?.id;
    final isLatestRunActive = latestRun?.isActive ?? false;
    final keepLiveOverlay = _shouldKeepLiveOverlay(latestRun);
    final liveAssistantText = keepLiveOverlay ? _liveAssistantText() : null;
    final liveThinkingText = keepLiveOverlay ? _liveThinkingText() : null;
    final liveToolSteps = keepLiveOverlay
        ? _liveToolSteps()
        : const <ThreadMessage>[];
    final isCancelling = _shouldKeepCancelling(latestRun);

    if (state.status == ThreadStatus.ready) {
      emit(
        ThreadState.ready(
          _agentId,
          agent: snapshot.agent,
          messages: snapshot.messages,
          latestRunId: latestRunId,
          isLatestRunActive: isLatestRunActive,
          followUpDraft: _followUpDraft,
          isCancelling: isCancelling,
          actionMessage: _actionMessage,
          liveAssistantText: liveAssistantText,
          liveThinkingText: liveThinkingText,
          liveToolSteps: liveToolSteps,
          models: _models,
          selectedModelId: _selectedModelId,
          agentUsage: snapshot.usage,
          usageMessage: snapshot.usageMessage,
        ),
      );
      return;
    }

    emit(
      ThreadState.cached(
        _agentId,
        agent: snapshot.agent,
        messages: snapshot.messages,
        latestRunId: latestRunId,
        isLatestRunActive: isLatestRunActive,
        followUpDraft: _followUpDraft,
        isCancelling: isCancelling,
        actionMessage: _actionMessage,
        liveAssistantText: liveAssistantText,
        liveThinkingText: liveThinkingText,
        liveToolSteps: liveToolSteps,
        models: _models,
        selectedModelId: _selectedModelId,
        agentUsage: snapshot.usage,
        usageMessage: snapshot.usageMessage,
      ),
    );
  }

  Future<void> _onStreamEvent(
    _ThreadStreamEvent event,
    Emitter<ThreadState> emit,
  ) async {
    if (event.runId != _streamingRunId) {
      return;
    }

    final sse = event.event;
    final isTerminalPayload = sse.event == 'result' || sse.event == 'done';
    if (_streamSuspended && !isTerminalPayload) {
      return;
    }
    if (_resetsReconnectAttempts(sse.event)) {
      _reconnectAttempts = 0;
    }
    if (sse.id != null && sse.id!.isNotEmpty) {
      _lastEventId = sse.id;
    }

    switch (sse.event) {
      case 'thinking':
        _liveThinkingBuffer.write(_extractDeltaText(sse.data));
        emit(state.copyWith(liveThinkingText: _liveThinkingBuffer.toString()));
      case 'assistant':
        _liveAssistantBuffer.write(_extractDeltaText(sse.data));
        emit(
          state.copyWith(liveAssistantText: _liveAssistantBuffer.toString()),
        );
      case 'tool_call':
        _upsertLiveToolStep(sse.data);
        emit(state.copyWith(liveToolSteps: _liveToolStepsById.values.toList()));
      case 'status':
        final runStatus = _extractRunStatus(sse.data);
        if (runStatus != null && !AgentRun.activeStatuses.contains(runStatus)) {
          emit(state.copyWith(isLatestRunActive: false));
          await _persistThinkingOnly(event.runId);
          if (isClosed) {
            return;
          }
          // Keep the SSE subscription briefly so a trailing result/done can
          // persist assistant text before teardown.
          _scheduleStatusFinalize(event.runId);
        } else if (runStatus != null) {
          emit(state.copyWith(isLatestRunActive: true, actionMessage: null));
        }
      case 'error':
        emit(
          _withActionMessage(
            _extractEventMessage(sse.data) ??
                'Cursor stream reported an error.',
            state,
          ),
        );
      case 'result':
        _statusFinalizeTimer?.cancel();
        _statusFinalizeTimer = null;
        await _persistStreamResult(event.runId, sse.data);
        if (isClosed) {
          return;
        }
        if (_streamSuspended) {
          return;
        }
        await _completeStreamingRun(emit, runId: event.runId);
      case 'done':
        _statusFinalizeTimer?.cancel();
        _statusFinalizeTimer = null;
        await _persistStreamResult(event.runId, sse.data);
        if (isClosed) {
          return;
        }
        if (_streamSuspended) {
          return;
        }
        await _completeStreamingRun(emit, runId: event.runId);
      default:
        break;
    }
  }

  Future<void> _onStreamFailed(
    _ThreadStreamFailed event,
    Emitter<ThreadState> emit,
  ) async {
    if (event.runId != _streamingRunId || _streamSuspended) {
      return;
    }

    final error = event.error;
    if (error is ApiException && error.statusCode == 410) {
      emit(_withActionMessage('Stream expired. Polling run status.', state));
      _startPolling(event.runId);
      return;
    }
    if (error is UnauthorizedException) {
      await _finalizeStreamingRun(
        event.runId,
        refresh: false,
        clearOverlay: false,
      );
      if (isClosed) {
        return;
      }
      final callback = _onUnauthorized;
      if (callback != null) {
        await callback();
      }
      _actionMessage = error.message;
      emit(
        ThreadState.failure(
          _agentId,
          error.message,
          agent: state.agent ?? _lastAgent,
          messages: state.messages.isNotEmpty ? state.messages : _lastMessages,
          latestRunId: state.latestRunId ?? _lastLatestRunId,
          isLatestRunActive: false,
          followUpDraft: _followUpDraft,
          actionMessage: error.message,
          models: _models,
          selectedModelId: _selectedModelId,
          agentUsage: state.agentUsage,
          usageMessage: state.usageMessage,
        ),
      );
      return;
    }

    if (_isInvalidLastEventId(error)) {
      if (!_retriedInvalidLastEventId) {
        _retriedInvalidLastEventId = true;
        _lastEventId = null;
        emit(
          _withActionMessage(
            'Stream resume expired. Reconnecting from latest events.',
            state,
          ),
        );
        _scheduleReconnect(
          event.runId,
          message: 'Stream resume expired. Reconnecting from latest events.',
        );
        return;
      }
      emit(
        _withActionMessage('Stream resume failed. Polling run status.', state),
      );
      _startPolling(event.runId);
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      await _finalizeStreamingRun(event.runId, refresh: false);
      if (isClosed) {
        return;
      }
      emit(
        _withActionMessage(
          'Stream disconnected. Pull to refresh for the latest run status.',
          _clearLiveOverlay(state.copyWith(isLatestRunActive: false)),
        ),
      );
      return;
    }

    if (error is RateLimitedException) {
      const message = 'Rate limited, retrying stream...';
      emit(_withActionMessage(message, state));
      _scheduleReconnect(event.runId, message: message);
      return;
    }

    if (error == null) {
      if (!state.isLatestRunActive) {
        await _completeStreamingRun(
          emit,
          runId: event.runId,
          markInactive: true,
        );
        return;
      }
      _scheduleReconnect(event.runId);
      return;
    }

    const message = 'Stream disconnected, retrying...';
    emit(_withActionMessage(message, state));
    _scheduleReconnect(event.runId, message: message);
  }

  Future<void> _onPollTick(
    _ThreadPollTick event,
    Emitter<ThreadState> emit,
  ) async {
    if (event.runId != _streamingRunId || _streamSuspended) {
      return;
    }
    try {
      final run = await _repository.loadRun(_agentId, event.runId);
      if (!run.isActive) {
        await _completeStreamingRun(emit, runId: event.runId);
      }
    } catch (_) {
      // Transient poll failure; keep polling until the next tick.
    }
  }

  void _onStreamRefreshTick(
    _ThreadStreamRefreshTick event,
    Emitter<ThreadState> emit,
  ) {
    if (event.runId == _streamingRunId) {
      add(const ThreadRefreshed());
    }
  }

  Future<void> _onStatusFinalize(
    _ThreadStatusFinalize event,
    Emitter<ThreadState> emit,
  ) async {
    if (event.runId != _streamingRunId || _streamSuspended) {
      return;
    }
    await _completeStreamingRun(
      emit,
      runId: event.runId,
      markInactive: true,
    );
  }

  void _scheduleStatusFinalize(String runId) {
    _statusFinalizeTimer?.cancel();
    _statusFinalizeTimer = Timer(const Duration(milliseconds: 750), () {
      if (_streamingRunId == runId && !_streamSuspended) {
        add(_ThreadStatusFinalize(runId));
      }
    });
  }

  Future<void> _persistThinkingOnly(String runId) async {
    final thinkingText = _blankToNull(_liveThinkingBuffer.toString());
    if (thinkingText == null) {
      return;
    }
    await _repository.saveRunThinking(
      agentId: _agentId,
      runId: runId,
      text: thinkingText,
    );
  }

  /// Sync stream ownership with the latest run.
  ///
  /// Returns a reloaded [ThreadSnapshot] when inactive-stream thinking was
  /// persisted and callers should emit the refreshed message list.
  Future<ThreadSnapshot?> _syncStreamForLatestRun(AgentRun? latestRun) async {
    final isActive = latestRun?.isActive ?? false;
    if (!isActive) {
      final runId = _streamingRunId;
      if (runId == null) {
        return null;
      }
      final hadThinking = _blankToNull(_liveThinkingBuffer.toString()) != null;
      await _finalizeStreamingRun(runId, refresh: false);
      if (!hadThinking || isClosed) {
        return null;
      }
      try {
        return await _repository.load(_agentId);
      } catch (error, stackTrace) {
        developer.log(
          'Unable to reload thread after persisting thinking.',
          name: 'ThreadBloc',
          error: error,
          stackTrace: stackTrace,
        );
        return null;
      }
    }
    if (_streamingRunId == latestRun!.id) {
      return null;
    }
    await _startStreaming(latestRun.id);
    return null;
  }

  Future<void> _startStreaming(String runId) async {
    final previousRunId = _streamingRunId;
    if (previousRunId != null && previousRunId != runId) {
      await _finalizeStreamingRun(previousRunId, refresh: false);
      if (isClosed) {
        return;
      }
    } else if (previousRunId == runId) {
      return;
    } else {
      _stopStreaming();
    }
    _streamingRunId = runId;
    _reconnectAttempts = 0;
    _retriedInvalidLastEventId = false;
    _startStreamRefreshTimer(runId);
    _attachStream(runId);
  }

  void _attachStream(String runId, {String? lastEventId}) {
    _streamSubscription?.cancel();
    _pollTimer?.cancel();
    _pollTimer = null;
    _streamSubscription = _repository
        .streamRun(_agentId, runId, lastEventId: lastEventId)
        .listen(
          (event) => add(_ThreadStreamEvent(runId, event)),
          onError: (Object error) => add(_ThreadStreamFailed(runId, error)),
          onDone: () => add(_ThreadStreamFailed(runId, null)),
          cancelOnError: true,
        );
  }

  void _startStreamRefreshTimer(String runId) {
    _streamRefreshTimer?.cancel();
    if (_streamRefreshInterval <= Duration.zero) {
      return;
    }
    _streamRefreshTimer = Timer.periodic(_streamRefreshInterval, (_) {
      if (_streamingRunId == runId) {
        add(_ThreadStreamRefreshTick(runId));
      }
    });
  }

  void _startPolling(String runId) {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _streamRefreshTimer?.cancel();
    _streamRefreshTimer = null;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => add(_ThreadPollTick(runId)),
    );
  }

  void _scheduleReconnect(String runId, {String? message}) {
    _reconnectTimer?.cancel();
    _reconnectAttempts += 1;
    if (message != null) {
      _actionMessage = message;
    }
    if (_refreshEveryReconnectFailures > 0 &&
        _reconnectAttempts % _refreshEveryReconnectFailures == 0) {
      add(const ThreadRefreshed());
    }
    _reconnectTimer = Timer(_reconnectBackoff(_reconnectAttempts), () {
      if (_streamingRunId == runId) {
        _attachStream(runId, lastEventId: _lastEventId);
      }
    });
  }

  Future<void> _completeStreamingRun(
    Emitter<ThreadState> emit, {
    required String runId,
    bool markInactive = false,
  }) {
    return _finalizeStreamingRun(
      runId,
      emit: emit,
      markInactive: markInactive,
      refresh: true,
    );
  }

  /// Detach transports first, await thinking persist, then clear local state.
  Future<void> _finalizeStreamingRun(
    String runId, {
    Emitter<ThreadState>? emit,
    bool markInactive = false,
    bool refresh = true,
    bool clearOverlay = true,
  }) async {
    if (_streamingRunId != runId) {
      return;
    }
    _detachStreamTransports();
    _streamSuspended = true;
    final thinkingText = _blankToNull(_liveThinkingBuffer.toString());
    final assistantText = _blankToNull(_liveAssistantBuffer.toString());
    if (thinkingText != null) {
      await _repository.saveRunThinking(
        agentId: _agentId,
        runId: runId,
        text: thinkingText,
      );
    }
    if (isClosed) {
      return;
    }
    if (_streamingRunId != runId) {
      _streamSuspended = false;
      return;
    }
    // Safety net when no result/done persisted the assistant reply yet.
    if (assistantText != null && !_runResultPersisted) {
      await _repository.saveRunResult(
        agentId: _agentId,
        runId: runId,
        text: assistantText,
      );
    }
    if (isClosed) {
      return;
    }
    if (_streamingRunId != runId) {
      _streamSuspended = false;
      return;
    }
    _clearStreamLocalState();
    if (emit != null && clearOverlay) {
      final next = markInactive
          ? state.copyWith(isLatestRunActive: false)
          : state;
      emit(_clearLiveOverlay(next));
    }
    if (refresh) {
      add(const ThreadRefreshed());
    }
  }

  void _detachStreamTransports() {
    _statusFinalizeTimer?.cancel();
    _statusFinalizeTimer = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _streamRefreshTimer?.cancel();
    _streamRefreshTimer = null;
  }

  void _clearStreamLocalState() {
    _streamingRunId = null;
    _lastEventId = null;
    _reconnectAttempts = 0;
    _retriedInvalidLastEventId = false;
    _streamSuspended = false;
    _runResultPersisted = false;
    _liveAssistantBuffer.clear();
    _liveThinkingBuffer.clear();
    _liveToolStepsById.clear();
  }

  void _stopStreaming() {
    _detachStreamTransports();
    _clearStreamLocalState();
  }

  Duration _reconnectBackoff(int attempt) {
    var milliseconds = _reconnectDelay.inMilliseconds;
    for (var i = 1; i < attempt; i += 1) {
      milliseconds *= 2;
      if (milliseconds >= _maxReconnectDelay.inMilliseconds) {
        return _maxReconnectDelay;
      }
    }
    return Duration(milliseconds: milliseconds);
  }

  bool _resetsReconnectAttempts(String event) {
    return switch (event) {
      'assistant' || 'thinking' || 'tool_call' || 'result' => true,
      _ => false,
    };
  }

  ThreadState _clearLiveOverlay(ThreadState base) {
    return base.copyWith(
      liveAssistantText: null,
      liveThinkingText: null,
      liveToolSteps: const [],
    );
  }

  bool _shouldKeepLiveOverlay(AgentRun? latestRun) {
    final latestRunId = latestRun?.id;
    return (latestRun?.isActive ?? false) &&
        latestRunId == state.latestRunId &&
        _streamingRunId == latestRunId;
  }

  bool _shouldKeepCancelling(AgentRun? latestRun) {
    final latestRunId = latestRun?.id;
    return state.isCancelling &&
        (latestRun?.isActive ?? false) &&
        latestRunId == state.latestRunId;
  }

  String? _liveAssistantText() {
    return _blankToNull(_liveAssistantBuffer.toString()) ??
        state.liveAssistantText;
  }

  String? _liveThinkingText() {
    return _blankToNull(_liveThinkingBuffer.toString()) ??
        state.liveThinkingText;
  }

  List<ThreadMessage> _liveToolSteps() {
    final buffered = _liveToolStepsById.values.toList(growable: false);
    return buffered.isNotEmpty ? buffered : state.liveToolSteps;
  }

  String _extractDeltaText(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        final map = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final text = map['text'] ?? map['delta'] ?? map['content'];
        if (text is String) {
          return text;
        }
      }
      if (decoded is String) {
        return decoded;
      }
    } on FormatException {
      // Not JSON; treat the raw payload as plain text.
    }
    return data;
  }

  Future<void> _persistStreamResult(String runId, String data) async {
    final resultText =
        _extractResultText(data) ??
        _blankToNull(_liveAssistantBuffer.toString());
    if (resultText == null) {
      return;
    }
    await _repository.saveRunResult(
      agentId: _agentId,
      runId: runId,
      text: resultText,
    );
    _runResultPersisted = true;
  }

  String? _extractResultText(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        final map = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        return _firstString(map, const [
              'text',
              'resultText',
              'result_text',
              'content',
              'summary',
              'output',
              'message',
            ]) ??
            _nestedString(map['result']) ??
            _nestedString(map['response']) ??
            _nestedString(map['output']);
      }
      if (decoded is String) {
        return _blankToNull(decoded);
      }
    } on FormatException {
      return _blankToNull(data);
    }
    return null;
  }

  String? _extractEventMessage(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        final map = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        return _firstString(map, const ['message', 'error', 'detail']);
      }
      if (decoded is String) {
        return _blankToNull(decoded);
      }
    } on FormatException {
      return _blankToNull(data);
    }
    return null;
  }

  String? _extractRunStatus(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        final map = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        return _firstString(map, const ['status', 'state'])?.toUpperCase();
      }
      if (decoded is String) {
        return _blankToNull(decoded)?.toUpperCase();
      }
    } on FormatException {
      return _blankToNull(data)?.toUpperCase();
    }
    return null;
  }

  bool _isInvalidLastEventId(Object? error) {
    return error is ApiException &&
        error.statusCode == 400 &&
        (error.code == 'invalid_last_event_id' ||
            error.message.toLowerCase().contains('invalid_last_event_id'));
  }

  String? _nestedString(Object? value) {
    if (value is String) {
      return _blankToNull(value);
    }
    if (value is Map) {
      final map = value.map((key, value) => MapEntry(key.toString(), value));
      return _firstString(map, const [
        'text',
        'content',
        'summary',
        'output',
        'message',
      ]);
    }
    return null;
  }

  String? _firstString(Map<String, Object?> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  void _upsertLiveToolStep(String data) {
    Map<String, Object?> step = const {};
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        step = decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      // Ignore malformed tool_call payloads.
    }

    final label =
        _stringAt(step, 'name') ??
        _stringAt(step, 'label') ??
        _stringAt(step, 'tool') ??
        'Tool step';
    final id =
        _stringAt(step, 'callId') ??
        _stringAt(step, 'call_id') ??
        '$label:${_indexAt(step) ?? _liveToolStepsById.length}';
    final status =
        _stringAt(step, 'status') ?? _stringAt(step, 'state') ?? 'running';
    final text = _stringAt(step, 'output') ?? _stringAt(step, 'text');

    _liveToolStepsById[id] = ToolStepMessage(
      id: 'live:$id',
      runId: _streamingRunId ?? _agentId,
      label: label,
      status: status,
      text: text,
      createdAt: DateTime.now().toUtc(),
    );
  }

  String? _stringAt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String? _indexAt(Map<String, Object?> json) {
    for (final key in const ['index', 'stepIndex', 'step_index']) {
      final value = json[key];
      if (value is int) {
        return value.toString();
      }
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  ThreadState _failurePreservingThread(String message) {
    final agent = state.agent ?? _lastAgent;
    final messages = state.messages.isNotEmpty ? state.messages : _lastMessages;
    final latestRunId = state.latestRunId ?? _lastLatestRunId;
    final isLatestRunActive = state.latestRunId != null
        ? state.isLatestRunActive
        : _lastIsLatestRunActive;
    return ThreadState.failure(
      _agentId,
      message,
      agent: agent,
      messages: messages,
      latestRunId: latestRunId,
      isLatestRunActive: isLatestRunActive,
      followUpDraft: _followUpDraft,
      actionMessage: _actionMessage,
      models: _models,
      selectedModelId: _selectedModelId,
      agentUsage: state.agentUsage,
      usageMessage: state.usageMessage,
    );
  }

  void _remember(ThreadSnapshot snapshot) {
    if (snapshot.agent != null) {
      _lastAgent = snapshot.agent;
    }
    if (snapshot.messages.isNotEmpty) {
      _lastMessages = snapshot.messages;
    }
    final latestRun = snapshot.latestRun;
    if (latestRun != null) {
      _lastLatestRunId = latestRun.id;
      _lastIsLatestRunActive = latestRun.isActive;
    }
  }

  @override
  Future<void> close() async {
    await _cacheSubscription?.cancel();
    await _streamSubscription?.cancel();
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    _streamRefreshTimer?.cancel();
    return super.close();
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
