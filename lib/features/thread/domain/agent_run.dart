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
