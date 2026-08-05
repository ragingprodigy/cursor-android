import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/auth/data/auth_session_repository.dart';
import 'package:cursor/features/auth/domain/api_key_info.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ConnectEvent extends Equatable {
  const ConnectEvent();

  @override
  List<Object?> get props => const [];
}

class ConnectStarted extends ConnectEvent {
  const ConnectStarted();
}

class ConnectSubmitted extends ConnectEvent {
  const ConnectSubmitted(this.key);

  final String key;

  @override
  List<Object?> get props => [key];
}

class ConnectOpenDashboard extends ConnectEvent {
  const ConnectOpenDashboard();
}

enum ConnectStatus { initial, submitting, authenticated, failure }

class ConnectState extends Equatable {
  const ConnectState._({required this.status, this.info, this.message});

  const ConnectState.initial() : this._(status: ConnectStatus.initial);

  const ConnectState.submitting() : this._(status: ConnectStatus.submitting);

  const ConnectState.authenticated(ApiKeyInfo info)
    : this._(status: ConnectStatus.authenticated, info: info);

  const ConnectState.failure(String message)
    : this._(status: ConnectStatus.failure, message: message);

  final ConnectStatus status;
  final ApiKeyInfo? info;
  final String? message;

  bool get isSubmitting => status == ConnectStatus.submitting;

  @override
  List<Object?> get props => [status, info, message];
}

class ConnectBloc extends Bloc<ConnectEvent, ConnectState> {
  ConnectBloc(this._repository) : super(const ConnectState.initial()) {
    on<ConnectStarted>(_onStarted);
    on<ConnectSubmitted>(_onSubmitted);
    on<ConnectOpenDashboard>(_onOpenDashboard);
  }

  final AuthSessionRepository _repository;

  Future<void> _onStarted(
    ConnectStarted event,
    Emitter<ConnectState> emit,
  ) async {
    try {
      final info = await _repository.restore();
      if (info != null) {
        emit(ConnectState.authenticated(info));
      }
    } on AppException catch (error) {
      emit(ConnectState.failure(error.message));
    }
  }

  Future<void> _onSubmitted(
    ConnectSubmitted event,
    Emitter<ConnectState> emit,
  ) async {
    final key = event.key.trim();
    if (key.isEmpty) {
      emit(const ConnectState.failure('Enter an API key to connect.'));
      return;
    }

    emit(const ConnectState.submitting());

    try {
      final info = await _repository.connect(key);
      emit(ConnectState.authenticated(info));
    } on AppException catch (error) {
      emit(ConnectState.failure(error.message));
    } on ArgumentError catch (error) {
      emit(ConnectState.failure(error.message));
    } catch (_) {
      emit(const ConnectState.failure('Unable to connect. Please try again.'));
    }
  }

  void _onOpenDashboard(
    ConnectOpenDashboard event,
    Emitter<ConnectState> emit,
  ) {}
}
