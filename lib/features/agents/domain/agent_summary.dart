import 'package:equatable/equatable.dart';

class AgentSummary extends Equatable {
  const AgentSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.url,
    required this.latestRunId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String status;
  final Uri? url;
  final String? latestRunId;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props {
    return [id, name, status, url, latestRunId, createdAt, updatedAt];
  }
}
