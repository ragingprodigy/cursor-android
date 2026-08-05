import 'dart:async';

import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/thread/data/thread_repository.dart';
import 'package:cursor/features/thread/domain/agent_detail.dart';
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

class _ThreadCacheChanged extends ThreadEvent {
  const _ThreadCacheChanged(this.snapshot);

  final ThreadSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

enum ThreadStatus { loading, cached, ready, failure }

class ThreadState extends Equatable {
  const ThreadState._({
    required this.agentId,
    required this.status,
    required this.agent,
    required this.messages,
    required this.isOffline,
    required this.isStale,
    this.message,
  });

  const ThreadState.loading(String agentId)
    : this._(
        agentId: agentId,
        status: ThreadStatus.loading,
        agent: null,
        messages: const [],
        isOffline: false,
        isStale: false,
      );

  const ThreadState.cached(
    String agentId, {
    AgentDetail? agent,
    List<ThreadMessage> messages = const [],
    bool isOffline = false,
    bool isStale = false,
    String? message,
  }) : this._(
         agentId: agentId,
         status: ThreadStatus.cached,
         agent: agent,
         messages: messages,
         isOffline: isOffline,
         isStale: isStale,
         message: message,
       );

  const ThreadState.ready(
    String agentId, {
    required AgentDetail? agent,
    required List<ThreadMessage> messages,
  }) : this._(
         agentId: agentId,
         status: ThreadStatus.ready,
         agent: agent,
         messages: messages,
         isOffline: false,
         isStale: false,
       );

  const ThreadState.failure(
    String agentId,
    String message, {
    AgentDetail? agent,
    List<ThreadMessage> messages = const [],
  }) : this._(
         agentId: agentId,
         status: ThreadStatus.failure,
         agent: agent,
         messages: messages,
         isOffline: false,
         isStale: false,
         message: message,
       );

  final String agentId;
  final ThreadStatus status;
  final AgentDetail? agent;
  final List<ThreadMessage> messages;
  final bool isOffline;
  final bool isStale;
  final String? message;

  bool get isLoading => status == ThreadStatus.loading;

  @override
  List<Object?> get props {
    return [agentId, status, agent, messages, isOffline, isStale, message];
  }
}

class ThreadBloc extends Bloc<ThreadEvent, ThreadState> {
  factory ThreadBloc({
    required ThreadRepository repository,
    required String agentId,
  }) {
    return ThreadBloc._(repository, agentId);
  }

  ThreadBloc._(this._repository, this._agentId)
    : super(ThreadState.loading(_agentId)) {
    on<ThreadStarted>(_onStarted);
    on<ThreadRefreshed>(_onRefreshed);
    on<_ThreadCacheChanged>(_onCacheChanged);
  }

  final ThreadRepository _repository;
  final String _agentId;
  StreamSubscription<ThreadSnapshot>? _cacheSubscription;
  AgentDetail? _lastAgent;
  List<ThreadMessage> _lastMessages = const [];

  Future<void> _onStarted(
    ThreadStarted event,
    Emitter<ThreadState> emit,
  ) async {
    emit(ThreadState.loading(_agentId));
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
          ),
        );
        return;
      }
      emit(
        ThreadState.ready(
          _agentId,
          agent: snapshot.agent,
          messages: snapshot.messages,
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

  ThreadState _failurePreservingThread(String message) {
    final agent = state.agent ?? _lastAgent;
    final messages = state.messages.isNotEmpty ? state.messages : _lastMessages;
    return ThreadState.failure(
      _agentId,
      message,
      agent: agent,
      messages: messages,
    );
  }

  void _onCacheChanged(_ThreadCacheChanged event, Emitter<ThreadState> emit) {
    if (event.snapshot.agent == null && event.snapshot.messages.isEmpty) {
      if (state.status == ThreadStatus.loading) {
        return;
      }
    }

    _remember(event.snapshot);

    if (state.status == ThreadStatus.ready) {
      emit(
        ThreadState.ready(
          _agentId,
          agent: event.snapshot.agent,
          messages: event.snapshot.messages,
        ),
      );
      return;
    }

    emit(
      ThreadState.cached(
        _agentId,
        agent: event.snapshot.agent,
        messages: event.snapshot.messages,
      ),
    );
  }

  void _remember(ThreadSnapshot snapshot) {
    if (snapshot.agent != null) {
      _lastAgent = snapshot.agent;
    }
    if (snapshot.messages.isNotEmpty) {
      _lastMessages = snapshot.messages;
    }
  }

  @override
  Future<void> close() async {
    await _cacheSubscription?.cancel();
    return super.close();
  }
}
