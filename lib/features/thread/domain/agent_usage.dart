import 'package:equatable/equatable.dart';

class AgentUsage extends Equatable {
  const AgentUsage({required this.totalTokens, required this.runs});

  final int totalTokens;
  final List<RunUsage> runs;

  bool get isEmpty => totalTokens == 0 && runs.isEmpty;

  @override
  List<Object?> get props => [totalTokens, runs];
}

class RunUsage extends Equatable {
  const RunUsage({
    required this.runId,
    required this.totalTokens,
    this.inputTokens,
    this.outputTokens,
  });

  final String runId;
  final int totalTokens;
  final int? inputTokens;
  final int? outputTokens;

  @override
  List<Object?> get props => [runId, totalTokens, inputTokens, outputTokens];
}
