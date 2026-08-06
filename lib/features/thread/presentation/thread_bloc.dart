import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/sse_client.dart';
import 'package:cursor/features/thread/data/follow_up_draft_store.dart';
import 'package:cursor/features/thread/data/thread_repository.dart';
import 'package:cursor/features/thread/domain/agent_detail.dart';
import 'package:cursor/features/thread/domain/agent_run.dart';
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

class ThreadFollowUpSubmitted extends ThreadEvent {
  const ThreadFollowUpSubmitted(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
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
    this.liveToolSteps = const [],
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
    List<ThreadMessage> liveToolSteps = const [],
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
         liveToolSteps: liveToolSteps,
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
    List<ThreadMessage> liveToolSteps = const [],
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
         liveToolSteps: liveToolSteps,
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

  /// In-progress tool call steps streamed for the active run.
  final List<ThreadMessage> liveToolSteps;

  bool get isLoading => status == ThreadStatus.loading;

  bool get canSubmitFollowUp =>
      agent != null && !isLatestRunActive && !isSendingFollowUp;

  bool get canCancel =>
      isLatestRunActive && latestRunId != null && !isCancelling;

  /// [messages] plus any in-progress streaming overlay, in display order.
  List<ThreadMessage> get displayMessages {
    final hasLiveText =
        liveAssistantText != null && liveAssistantText!.isNotEmpty;
    if (liveToolSteps.isEmpty && !hasLiveText) {
      return messages;
    }
    final runId = latestRunId ?? agentId;
    return [
      ...messages,
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
    List<ThreadMessage>? liveToolSteps,
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
      liveToolSteps: liveToolSteps ?? this.liveToolSteps,
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
      liveToolSteps,
    ];
  }
}

class ThreadBloc extends Bloc<ThreadEvent, ThreadState> {
  factory ThreadBloc({
    required ThreadRepository repository,
    required FollowUpDraftStore draftStore,
    required String agentId,
    Duration pollInterval = const Duration(seconds: 3),
    Duration reconnectDelay = const Duration(seconds: 2),
    Duration maxReconnectDelay = const Duration(seconds: 60),
    int maxReconnectAttempts = 10,
    int refreshEveryReconnectFailures = 3,
    FutureOr<void> Function()? onUnauthorized,
  }) {
    return ThreadBloc._(
      repository,
      draftStore,
      agentId,
      pollInterval,
      reconnectDelay,
      maxReconnectDelay,
      maxReconnectAttempts,
      refreshEveryReconnectFailures,
      onUnauthorized,
    );
  }

  ThreadBloc._(
    this._repository,
    this._draftStore,
    this._agentId,
    this._pollInterval,
    this._reconnectDelay,
    this._maxReconnectDelay,
    this._maxReconnectAttempts,
    this._refreshEveryReconnectFailures,
    this._onUnauthorized,
  ) : super(ThreadState.loading(_agentId)) {
    on<ThreadStarted>(_onStarted);
    on<ThreadRefreshed>(_onRefreshed);
    on<ThreadFollowUpDraftChanged>(_onFollowUpDraftChanged);
    on<ThreadFollowUpSubmitted>(_onFollowUpSubmitted);
    on<ThreadCancelRequested>(_onCancelRequested);
    on<_ThreadCacheChanged>(_onCacheChanged);
    on<_ThreadStreamEvent>(_onStreamEvent);
    on<_ThreadStreamFailed>(_onStreamFailed);
    on<_ThreadPollTick>(_onPollTick);
  }

  final ThreadRepository _repository;
  final FollowUpDraftStore _draftStore;
  final String _agentId;
  final Duration _pollInterval;
  final Duration _reconnectDelay;
  final Duration _maxReconnectDelay;
  final int _maxReconnectAttempts;
  final int _refreshEveryReconnectFailures;
  final FutureOr<void> Function()? _onUnauthorized;

  StreamSubscription<ThreadSnapshot>? _cacheSubscription;
  StreamSubscription<SseEvent>? _streamSubscription;
  Timer? _pollTimer;
  Timer? _reconnectTimer;

  AgentDetail? _lastAgent;
  List<ThreadMessage> _lastMessages = const [];
  String? _lastLatestRunId;
  bool _lastIsLatestRunActive = false;

  String _followUpDraft = '';
  String? _actionMessage;
  String? _streamingRunId;
  String? _lastEventId;
  int _reconnectAttempts = 0;
  bool _retriedInvalidLastEventId = false;
  final StringBuffer _liveAssistantBuffer = StringBuffer();
  final Map<String, ToolStepMessage> _liveToolStepsById = {};

  Future<void> _onStarted(
    ThreadStarted event,
    Emitter<ThreadState> emit,
  ) async {
    emit(ThreadState.loading(_agentId));
    _followUpDraft = await _draftStore.load(_agentId);
    await _cacheSubscription?.cancel();
    _cacheSubscription = _repository.watchCache(_agentId).listen((snapshot) {
      add(_ThreadCacheChanged(snapshot));
    });
    add(const ThreadRefreshed());
  }

  Future<void> _onRefreshed(
    ThreadRefreshed event,
    Emitter<ThreadState> emit,
  ) async {
    try {
      final snapshot = await _repository.load(_agentId);
      _remember(snapshot);
      _syncStreamForLatestRun(snapshot.latestRun);
      if (snapshot.isStale) {
        emit(
          ThreadState.cached(
            _agentId,
            agent: snapshot.agent,
            messages: snapshot.messages,
            isOffline: snapshot.isOffline,
            isStale: true,
            message: snapshot.isOffline
                ? 'Showing cached thread while offline.'
                : 'Showing cached thread.',
            latestRunId: snapshot.latestRun?.id,
            isLatestRunActive: snapshot.latestRun?.isActive ?? false,
            followUpDraft: _followUpDraft,
            actionMessage: _actionMessage,
          ),
        );
        return;
      }
      emit(
        ThreadState.ready(
          _agentId,
          agent: snapshot.agent,
          messages: snapshot.messages,
          latestRunId: snapshot.latestRun?.id,
          isLatestRunActive: snapshot.latestRun?.isActive ?? false,
          followUpDraft: _followUpDraft,
          actionMessage: _actionMessage,
        ),
      );
    } on AppException catch (error) {
      emit(_failurePreservingThread(error.message));
    } catch (_) {
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
      run = await _repository.sendFollowUp(_agentId, text);
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
    _syncStreamForLatestRun(run);
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

  void _onCacheChanged(_ThreadCacheChanged event, Emitter<ThreadState> emit) {
    if (event.snapshot.agent == null && event.snapshot.messages.isEmpty) {
      if (state.status == ThreadStatus.loading) {
        return;
      }
    }

    _remember(event.snapshot);
    _syncStreamForLatestRun(event.snapshot.latestRun);

    final latestRunId = event.snapshot.latestRun?.id;
    final isLatestRunActive = event.snapshot.latestRun?.isActive ?? false;
    final keepLiveOverlay =
        isLatestRunActive &&
        latestRunId == state.latestRunId &&
        _streamingRunId == latestRunId;

    if (state.status == ThreadStatus.ready) {
      emit(
        ThreadState.ready(
          _agentId,
          agent: event.snapshot.agent,
          messages: event.snapshot.messages,
          latestRunId: latestRunId,
          isLatestRunActive: isLatestRunActive,
          followUpDraft: _followUpDraft,
          actionMessage: _actionMessage,
          liveAssistantText: keepLiveOverlay ? state.liveAssistantText : null,
          liveToolSteps: keepLiveOverlay ? state.liveToolSteps : const [],
        ),
      );
      return;
    }

    emit(
      ThreadState.cached(
        _agentId,
        agent: event.snapshot.agent,
        messages: event.snapshot.messages,
        latestRunId: latestRunId,
        isLatestRunActive: isLatestRunActive,
        followUpDraft: _followUpDraft,
        actionMessage: _actionMessage,
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
    _reconnectAttempts = 0;
    if (sse.id != null && sse.id!.isNotEmpty) {
      _lastEventId = sse.id;
    }

    switch (sse.event) {
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
          _stopStreaming();
          emit(_clearLiveOverlay(state.copyWith(isLatestRunActive: false)));
          add(const ThreadRefreshed());
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
        await _persistStreamResult(event.runId, sse.data);
        _stopStreaming();
        emit(_clearLiveOverlay(state));
        add(const ThreadRefreshed());
      case 'done':
        await _persistStreamResult(event.runId, sse.data);
        _stopStreaming();
        emit(_clearLiveOverlay(state));
        add(const ThreadRefreshed());
      default:
        break;
    }
  }

  Future<void> _onStreamFailed(
    _ThreadStreamFailed event,
    Emitter<ThreadState> emit,
  ) async {
    if (event.runId != _streamingRunId) {
      return;
    }

    final error = event.error;
    if (error is ApiException && error.statusCode == 410) {
      emit(_withActionMessage('Stream expired. Polling run status.', state));
      _startPolling(event.runId);
      return;
    }
    if (error is UnauthorizedException) {
      _stopStreaming();
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
      _stopStreaming();
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
    if (event.runId != _streamingRunId) {
      return;
    }
    try {
      final run = await _repository.loadRun(_agentId, event.runId);
      if (!run.isActive) {
        _stopStreaming();
        emit(_clearLiveOverlay(state));
        add(const ThreadRefreshed());
      }
    } catch (_) {
      // Transient poll failure; keep polling until the next tick.
    }
  }

  void _syncStreamForLatestRun(AgentRun? latestRun) {
    final isActive = latestRun?.isActive ?? false;
    if (!isActive) {
      _stopStreaming();
      return;
    }
    if (_streamingRunId == latestRun!.id) {
      return;
    }
    _startStreaming(latestRun.id);
  }

  void _startStreaming(String runId) {
    _stopStreaming();
    _streamingRunId = runId;
    _reconnectAttempts = 0;
    _retriedInvalidLastEventId = false;
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

  void _startPolling(String runId) {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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

  void _stopStreaming() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _streamingRunId = null;
    _lastEventId = null;
    _reconnectAttempts = 0;
    _retriedInvalidLastEventId = false;
    _liveAssistantBuffer.clear();
    _liveToolStepsById.clear();
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

  ThreadState _clearLiveOverlay(ThreadState base) {
    return base.copyWith(liveAssistantText: null, liveToolSteps: const []);
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
        error.message.toLowerCase().contains('invalid_last_event_id');
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
    return super.close();
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
