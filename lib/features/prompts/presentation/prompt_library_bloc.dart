import 'package:cursor/features/prompts/data/prompt_library_repository.dart';
import 'package:cursor/features/prompts/domain/saved_prompt.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class PromptLibraryEvent extends Equatable {
  const PromptLibraryEvent();

  @override
  List<Object?> get props => const [];
}

class PromptLibraryStarted extends PromptLibraryEvent {
  const PromptLibraryStarted();
}

class PromptLibraryQueryChanged extends PromptLibraryEvent {
  const PromptLibraryQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class PromptLibraryDeleteRequested extends PromptLibraryEvent {
  const PromptLibraryDeleteRequested(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

enum PromptLibraryStatus { initial, loading, ready, failure }

class PromptLibraryState extends Equatable {
  const PromptLibraryState({
    required this.status,
    this.prompts = const [],
    this.query = '',
    this.message,
  });

  const PromptLibraryState.initial()
    : this(status: PromptLibraryStatus.initial);

  final PromptLibraryStatus status;
  final List<SavedPrompt> prompts;
  final String query;
  final String? message;

  List<SavedPrompt> get visiblePrompts {
    if (query.trim().isEmpty) {
      return prompts;
    }
    return prompts
        .where((prompt) => prompt.matchesQuery(query))
        .toList(growable: false);
  }

  PromptLibraryState copyWith({
    PromptLibraryStatus? status,
    List<SavedPrompt>? prompts,
    String? query,
    Object? message = _sentinel,
  }) {
    return PromptLibraryState(
      status: status ?? this.status,
      prompts: prompts ?? this.prompts,
      query: query ?? this.query,
      message: message == _sentinel ? this.message : message as String?,
    );
  }

  @override
  List<Object?> get props => [status, prompts, query, message];
}

class PromptLibraryBloc extends Bloc<PromptLibraryEvent, PromptLibraryState> {
  PromptLibraryBloc(this._repository)
    : super(const PromptLibraryState.initial()) {
    on<PromptLibraryStarted>(_onStarted);
    on<PromptLibraryQueryChanged>(_onQueryChanged);
    on<PromptLibraryDeleteRequested>(_onDelete);
  }

  final PromptLibraryRepository _repository;

  Future<void> _onStarted(
    PromptLibraryStarted event,
    Emitter<PromptLibraryState> emit,
  ) async {
    emit(state.copyWith(status: PromptLibraryStatus.loading, message: null));
    await emit.forEach<List<SavedPrompt>>(
      _repository.watchAll(),
      onData: (prompts) {
        return state.copyWith(
          status: PromptLibraryStatus.ready,
          prompts: prompts,
          message: null,
        );
      },
      onError: (_, _) {
        return state.copyWith(
          status: PromptLibraryStatus.failure,
          message: 'Unable to load prompt library.',
        );
      },
    );
  }

  void _onQueryChanged(
    PromptLibraryQueryChanged event,
    Emitter<PromptLibraryState> emit,
  ) {
    emit(state.copyWith(query: event.query));
  }

  Future<void> _onDelete(
    PromptLibraryDeleteRequested event,
    Emitter<PromptLibraryState> emit,
  ) async {
    try {
      await _repository.delete(event.id);
    } catch (_) {
      emit(state.copyWith(message: 'Unable to delete prompt.'));
    }
  }
}

const _sentinel = Object();
