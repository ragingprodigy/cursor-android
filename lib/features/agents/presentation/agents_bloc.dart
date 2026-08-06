import 'dart:async';
import 'dart:developer' as developer;

import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/agents/data/agents_list_grouping_store.dart';
import 'package:cursor/features/agents/data/agents_repository.dart';
import 'package:cursor/features/agents/domain/agents_list_grouping.dart';
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

class AgentsGroupingChanged extends AgentsEvent {
  const AgentsGroupingChanged(this.grouping);

  final AgentsListGrouping grouping;

  @override
  List<Object?> get props => [grouping];
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
    required this.grouping,
    this.message,
  });

  const AgentsState.loading({
    AgentsListGrouping grouping = AgentsListGrouping.flat,
  }) : this._(
         status: AgentsStatus.loading,
         agents: const [],
         isOffline: false,
         isStale: false,
         grouping: grouping,
       );

  const AgentsState.cached(
    List<AgentSummary> agents, {
    bool isOffline = false,
    bool isStale = false,
    AgentsListGrouping grouping = AgentsListGrouping.flat,
    String? message,
  }) : this._(
         status: AgentsStatus.cached,
         agents: agents,
         isOffline: isOffline,
         isStale: isStale,
         grouping: grouping,
         message: message,
       );

  const AgentsState.ready(
    List<AgentSummary> agents, {
    AgentsListGrouping grouping = AgentsListGrouping.flat,
  }) : this._(
         status: AgentsStatus.ready,
         agents: agents,
         isOffline: false,
         isStale: false,
         grouping: grouping,
       );

  const AgentsState.failure(
    String message, {
    List<AgentSummary> agents = const [],
    AgentsListGrouping grouping = AgentsListGrouping.flat,
  }) : this._(
         status: AgentsStatus.failure,
         agents: agents,
         isOffline: false,
         isStale: false,
         grouping: grouping,
         message: message,
       );

  final AgentsStatus status;
  final List<AgentSummary> agents;
  final bool isOffline;
  final bool isStale;
  final AgentsListGrouping grouping;
  final String? message;

  bool get isLoading => status == AgentsStatus.loading;

  @override
  List<Object?> get props {
    return [status, agents, isOffline, isStale, grouping, message];
  }
}

class AgentsBloc extends Bloc<AgentsEvent, AgentsState> {
  AgentsBloc(this._repository, {AgentsListGroupingStore? groupingStore})
    : _groupingStore = groupingStore ?? AgentsListGroupingStore(),
      super(const AgentsState.loading()) {
    on<AgentsStarted>(_onStarted);
    on<AgentsRefreshed>(_onRefreshed);
    on<AgentsGroupingChanged>(_onGroupingChanged);
    on<_AgentsCacheChanged>(_onCacheChanged);
  }

  final AgentsRepository _repository;
  final AgentsListGroupingStore _groupingStore;
  StreamSubscription<AgentsSnapshot>? _cacheSubscription;
  List<AgentSummary> _lastCachedAgents = const [];

  Future<void> _onStarted(
    AgentsStarted event,
    Emitter<AgentsState> emit,
  ) async {
    final grouping = await _loadGrouping();
    emit(AgentsState.loading(grouping: grouping));
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
            grouping: state.grouping,
            message: snapshot.isOffline
                ? 'Showing cached agents while offline.'
                : 'Showing cached agents.',
          ),
        );
        return;
      }
      emit(AgentsState.ready(snapshot.agents, grouping: state.grouping));
    } on AppException catch (error) {
      emit(_failurePreservingAgents(error.message));
    } catch (_) {
      emit(_failurePreservingAgents('Unable to load agents.'));
    } finally {
      event.completer?.complete();
    }
  }

  AgentsState _failurePreservingAgents(String message) {
    final agents = _agentsToPreserve();
    if (agents.isEmpty) {
      return AgentsState.failure(message, grouping: state.grouping);
    }
    return AgentsState.failure(
      message,
      agents: agents,
      grouping: state.grouping,
    );
  }

  List<AgentSummary> _agentsToPreserve() {
    if (state.agents.isNotEmpty) {
      return state.agents;
    }
    if (_lastCachedAgents.isNotEmpty) {
      return _lastCachedAgents;
    }
    return const [];
  }

  void _onCacheChanged(_AgentsCacheChanged event, Emitter<AgentsState> emit) {
    if (event.snapshot.agents.isNotEmpty) {
      _lastCachedAgents = event.snapshot.agents;
    }

    if (event.snapshot.agents.isEmpty && state.status == AgentsStatus.loading) {
      return;
    }

    if (state.status == AgentsStatus.ready) {
      emit(AgentsState.ready(event.snapshot.agents, grouping: state.grouping));
      return;
    }

    emit(AgentsState.cached(event.snapshot.agents, grouping: state.grouping));
  }

  Future<void> _onGroupingChanged(
    AgentsGroupingChanged event,
    Emitter<AgentsState> emit,
  ) async {
    if (event.grouping == state.grouping) {
      return;
    }

    emit(_stateWithGrouping(event.grouping));
    try {
      await _groupingStore.save(event.grouping);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to save agents grouping preference.',
        name: 'AgentsBloc',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<AgentsListGrouping> _loadGrouping() async {
    try {
      return await _groupingStore.load();
    } catch (error, stackTrace) {
      developer.log(
        'Unable to load agents grouping preference.',
        name: 'AgentsBloc',
        error: error,
        stackTrace: stackTrace,
      );
      return AgentsListGrouping.flat;
    }
  }

  AgentsState _stateWithGrouping(AgentsListGrouping grouping) {
    return switch (state.status) {
      AgentsStatus.loading => AgentsState.loading(grouping: grouping),
      AgentsStatus.cached => AgentsState.cached(
        state.agents,
        isOffline: state.isOffline,
        isStale: state.isStale,
        grouping: grouping,
        message: state.message,
      ),
      AgentsStatus.ready => AgentsState.ready(state.agents, grouping: grouping),
      AgentsStatus.failure => AgentsState.failure(
        state.message ?? 'Unable to load agents.',
        agents: state.agents,
        grouping: grouping,
      ),
    };
  }

  @override
  Future<void> close() async {
    await _cacheSubscription?.cancel();
    return super.close();
  }
}
