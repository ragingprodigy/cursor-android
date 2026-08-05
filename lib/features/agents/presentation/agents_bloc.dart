import 'dart:async';

import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/agents/data/agents_repository.dart';
import 'package:cursor/features/agents/domain/agent_summary.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class AgentsEvent extends Equatable {
  const AgentsEvent();

  @override
  List<Object?> get props => const [];
}

class AgentsStarted extends AgentsEvent {
  const AgentsStarted();
}

class AgentsRefreshed extends AgentsEvent {
  const AgentsRefreshed({this.completer});

  final Completer<void>? completer;
}

class _AgentsCacheChanged extends AgentsEvent {
  const _AgentsCacheChanged(this.snapshot);

  final AgentsSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

enum AgentsStatus { loading, cached, ready, failure }

class AgentsState extends Equatable {
  const AgentsState._({
    required this.status,
    required this.agents,
    required this.isOffline,
    required this.isStale,
    this.message,
  });

  const AgentsState.loading()
    : this._(
        status: AgentsStatus.loading,
        agents: const [],
        isOffline: false,
        isStale: false,
      );

  const AgentsState.cached(
    List<AgentSummary> agents, {
    bool isOffline = false,
    bool isStale = false,
    String? message,
  }) : this._(
         status: AgentsStatus.cached,
         agents: agents,
         isOffline: isOffline,
         isStale: isStale,
         message: message,
       );

  const AgentsState.ready(List<AgentSummary> agents)
    : this._(
        status: AgentsStatus.ready,
        agents: agents,
        isOffline: false,
        isStale: false,
      );

  const AgentsState.failure(String message)
    : this._(
        status: AgentsStatus.failure,
        agents: const [],
        isOffline: false,
        isStale: false,
        message: message,
      );

  final AgentsStatus status;
  final List<AgentSummary> agents;
  final bool isOffline;
  final bool isStale;
  final String? message;

  bool get isLoading => status == AgentsStatus.loading;

  @override
  List<Object?> get props => [status, agents, isOffline, isStale, message];
}

class AgentsBloc extends Bloc<AgentsEvent, AgentsState> {
  AgentsBloc(this._repository) : super(const AgentsState.loading()) {
    on<AgentsStarted>(_onStarted);
    on<AgentsRefreshed>(_onRefreshed);
    on<_AgentsCacheChanged>(_onCacheChanged);
  }

  final AgentsRepository _repository;
  StreamSubscription<AgentsSnapshot>? _cacheSubscription;

  Future<void> _onStarted(
    AgentsStarted event,
    Emitter<AgentsState> emit,
  ) async {
    emit(const AgentsState.loading());
    await _cacheSubscription?.cancel();
    _cacheSubscription = _repository.watchCached().listen((snapshot) {
      add(_AgentsCacheChanged(snapshot));
    });
    add(const AgentsRefreshed());
  }

  Future<void> _onRefreshed(
    AgentsRefreshed event,
    Emitter<AgentsState> emit,
  ) async {
    try {
      final snapshot = await _repository.refresh();
      if (snapshot.isStale) {
        emit(
          AgentsState.cached(
            snapshot.agents,
            isOffline: snapshot.isOffline,
            isStale: true,
            message: snapshot.isOffline
                ? 'Showing cached agents while offline.'
                : 'Showing cached agents.',
          ),
        );
        return;
      }
      emit(AgentsState.ready(snapshot.agents));
    } on AppException catch (error) {
      emit(AgentsState.failure(error.message));
    } catch (_) {
      emit(const AgentsState.failure('Unable to load agents.'));
    } finally {
      event.completer?.complete();
    }
  }

  void _onCacheChanged(_AgentsCacheChanged event, Emitter<AgentsState> emit) {
    if (event.snapshot.agents.isEmpty && state.status == AgentsStatus.loading) {
      return;
    }

    if (state.status == AgentsStatus.ready) {
      emit(AgentsState.ready(event.snapshot.agents));
      return;
    }

    emit(AgentsState.cached(event.snapshot.agents));
  }

  @override
  Future<void> close() async {
    await _cacheSubscription?.cancel();
    return super.close();
  }
}
