import 'package:cursor/features/usage/data/usage_repository.dart';
import 'package:cursor/features/usage/domain/usage_report.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class UsageEvent extends Equatable {
  const UsageEvent();

  @override
  List<Object?> get props => const [];
}

class UsageStarted extends UsageEvent {
  const UsageStarted();
}

class UsagePresetSelected extends UsageEvent {
  const UsagePresetSelected(this.preset);

  final UsagePreset preset;

  @override
  List<Object?> get props => [preset];
}

class UsageCustomRangeSelected extends UsageEvent {
  const UsageCustomRangeSelected({
    required this.startDate,
    required this.endDate,
  });

  final DateTime startDate;
  final DateTime endDate;

  @override
  List<Object?> get props => [startDate, endDate];
}

class UsageRefreshed extends UsageEvent {
  const UsageRefreshed();
}

enum UsagePreset { last7Days, last30Days, custom }

enum UsageStatus { initial, loading, ready }

class UsageState extends Equatable {
  const UsageState({
    required this.status,
    required this.preset,
    required this.startDate,
    required this.endDate,
    this.report,
    this.message,
  });

  factory UsageState.initial() {
    final range = _rangeForPreset(UsagePreset.last7Days);
    return UsageState(
      status: UsageStatus.initial,
      preset: UsagePreset.last7Days,
      startDate: range.$1,
      endDate: range.$2,
    );
  }

  final UsageStatus status;
  final UsagePreset preset;
  final DateTime startDate;
  final DateTime endDate;
  final UsageReport? report;
  final String? message;

  bool get isLoading => status == UsageStatus.loading;

  UsageState copyWith({
    UsageStatus? status,
    UsagePreset? preset,
    DateTime? startDate,
    DateTime? endDate,
    UsageReport? report,
    Object? message = _sentinel,
  }) {
    return UsageState(
      status: status ?? this.status,
      preset: preset ?? this.preset,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      report: report ?? this.report,
      message: message == _sentinel ? this.message : message as String?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    preset,
    startDate,
    endDate,
    report,
    message,
  ];
}

class UsageBloc extends Bloc<UsageEvent, UsageState> {
  UsageBloc(this._repository) : super(UsageState.initial()) {
    on<UsageStarted>(_onStarted);
    on<UsagePresetSelected>(_onPresetSelected);
    on<UsageCustomRangeSelected>(_onCustomRangeSelected);
    on<UsageRefreshed>(_onRefreshed);
  }

  final UsageRepository _repository;

  Future<void> _onStarted(UsageStarted event, Emitter<UsageState> emit) {
    return _load(
      emit,
      preset: state.preset,
      range: (state.startDate, state.endDate),
    );
  }

  Future<void> _onPresetSelected(
    UsagePresetSelected event,
    Emitter<UsageState> emit,
  ) {
    if (event.preset == UsagePreset.custom) {
      return _load(
        emit,
        preset: UsagePreset.custom,
        range: (state.startDate, state.endDate),
      );
    }
    final range = _rangeForPreset(event.preset);
    return _load(emit, preset: event.preset, range: range);
  }

  Future<void> _onCustomRangeSelected(
    UsageCustomRangeSelected event,
    Emitter<UsageState> emit,
  ) {
    final range = _clampRange(event.startDate, event.endDate);
    return _load(emit, preset: UsagePreset.custom, range: range);
  }

  Future<void> _onRefreshed(UsageRefreshed event, Emitter<UsageState> emit) {
    return _load(
      emit,
      preset: state.preset,
      range: (state.startDate, state.endDate),
    );
  }

  Future<void> _load(
    Emitter<UsageState> emit, {
    required UsagePreset preset,
    required (DateTime, DateTime) range,
  }) async {
    emit(
      state.copyWith(
        status: UsageStatus.loading,
        preset: preset,
        startDate: range.$1,
        endDate: range.$2,
        message: null,
      ),
    );
    try {
      final report = await _repository.loadReport(
        startDate: range.$1,
        endDate: range.$2,
      );
      emit(
        state.copyWith(
          status: UsageStatus.ready,
          preset: preset,
          startDate: report.startDate,
          endDate: report.endDate,
          report: report,
          message: report.message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: UsageStatus.ready,
          preset: preset,
          startDate: range.$1,
          endDate: range.$2,
          message: 'Unable to load usage: $error',
        ),
      );
    }
  }
}

(DateTime, DateTime) _rangeForPreset(UsagePreset preset) {
  final end = DateTime.now().toUtc();
  final days = switch (preset) {
    UsagePreset.last7Days => 7,
    UsagePreset.last30Days || UsagePreset.custom => 30,
  };
  return (end.subtract(Duration(days: days)), end);
}

(DateTime, DateTime) _clampRange(DateTime startDate, DateTime endDate) {
  var start = DateTime.utc(startDate.year, startDate.month, startDate.day);
  var end = DateTime.utc(
    endDate.year,
    endDate.month,
    endDate.day,
    23,
    59,
    59,
    999,
  );
  if (end.isBefore(start)) {
    final previousStart = start;
    start = end;
    end = previousStart;
  }
  const maxRange = Duration(days: 30);
  if (end.difference(start) > maxRange) {
    start = end.subtract(maxRange);
  }
  return (start, end);
}

const _sentinel = Object();
