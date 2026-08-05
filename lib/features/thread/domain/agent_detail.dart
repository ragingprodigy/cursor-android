import 'package:equatable/equatable.dart';

class AgentDetail extends Equatable {
  const AgentDetail({
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

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      if (url != null) 'url': url.toString(),
      if (latestRunId != null) 'latestRunId': latestRunId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  List<Object?> get props {
    return [id, name, status, url, latestRunId, createdAt, updatedAt];
  }
}
