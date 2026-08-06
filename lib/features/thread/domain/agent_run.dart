import 'dart:convert';

import 'package:equatable/equatable.dart';

class AgentRun extends Equatable {
  const AgentRun({
    required this.id,
    required this.status,
    required this.createdAt,
    this.agentId,
    this.promptText,
    this.resultText,
    this.updatedAt,
    this.payload = const {},
  });

  final String id;
  final String? agentId;
  final String status;
  final String? promptText;
  final String? resultText;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, Object?> payload;

  static const activeStatuses = {'CREATING', 'RUNNING'};

  bool get isActive => activeStatuses.contains(status.toUpperCase());

  AgentRun copyWith({
    String? id,
    String? agentId,
    String? status,
    String? promptText,
    String? resultText,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, Object?>? payload,
  }) {
    return AgentRun(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      status: status ?? this.status,
      promptText: promptText ?? this.promptText,
      resultText: resultText ?? this.resultText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      payload: payload ?? this.payload,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      if (agentId != null) 'agentId': agentId,
      'status': status,
      if (promptText != null) 'promptText': promptText,
      if (resultText != null) 'resultText': resultText,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      if (payload.isNotEmpty) 'payload': payload,
    };
  }

  @override
  List<Object?> get props {
    return [
      id,
      agentId,
      status,
      promptText,
      resultText,
      createdAt,
      updatedAt,
      jsonEncode(payload),
    ];
  }
}
