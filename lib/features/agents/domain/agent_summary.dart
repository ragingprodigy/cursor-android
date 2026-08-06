import 'package:equatable/equatable.dart';

class AgentSummary extends Equatable {
  const AgentSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.url,
    required this.repoUrl,
    required this.latestRunId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String status;
  final Uri? url;
  final String? repoUrl;
  final String? latestRunId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgentSummary copyWith({
    String? id,
    String? name,
    String? status,
    Uri? url,
    String? repoUrl,
    String? latestRunId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgentSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      url: url ?? this.url,
      repoUrl: repoUrl ?? this.repoUrl,
      latestRunId: latestRunId ?? this.latestRunId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props {
    return [id, name, status, url, repoUrl, latestRunId, createdAt, updatedAt];
  }
}
