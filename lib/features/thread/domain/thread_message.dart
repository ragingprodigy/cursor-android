import 'package:equatable/equatable.dart';

sealed class ThreadMessage extends Equatable {
  const ThreadMessage({
    required this.id,
    required this.runId,
    required this.createdAt,
  });

  final String id;
  final String runId;
  final DateTime createdAt;
}

class UserMessage extends ThreadMessage {
  const UserMessage({
    required super.id,
    required super.runId,
    required super.createdAt,
    required this.text,
  });

  final String text;

  @override
  List<Object?> get props => [id, runId, createdAt, text];
}

class AssistantMessage extends ThreadMessage {
  const AssistantMessage({
    required super.id,
    required super.runId,
    required super.createdAt,
    required this.text,
    this.status,
  });

  final String text;
  final String? status;

  @override
  List<Object?> get props => [id, runId, createdAt, text, status];
}

class ToolStepMessage extends ThreadMessage {
  const ToolStepMessage({
    required super.id,
    required super.runId,
    required super.createdAt,
    required this.label,
    required this.status,
    this.text,
  });

  final String label;
  final String status;
  final String? text;

  @override
  List<Object?> get props => [id, runId, createdAt, label, status, text];
}
