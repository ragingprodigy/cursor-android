import 'package:cursor/features/agents/domain/agent_summary.dart';
import 'package:equatable/equatable.dart';

enum AgentsListGrouping {
  flat,
  byRepository,
  byStatus;

  String get label {
    return switch (this) {
      AgentsListGrouping.flat => 'Flat',
      AgentsListGrouping.byRepository => 'By repository',
      AgentsListGrouping.byStatus => 'By status',
    };
  }

  static AgentsListGrouping fromName(String? name) {
    return AgentsListGrouping.values.firstWhere(
      (grouping) => grouping.name == name,
      orElse: () => AgentsListGrouping.flat,
    );
  }
}

class AgentsListSection extends Equatable {
  const AgentsListSection({required this.title, required this.agents});

  final String title;
  final List<AgentSummary> agents;

  @override
  List<Object?> get props => [title, agents];
}

List<AgentsListSection> groupAgents(
  List<AgentSummary> agents,
  AgentsListGrouping grouping,
) {
  return switch (grouping) {
    AgentsListGrouping.flat => [
      AgentsListSection(title: grouping.label, agents: agents),
    ],
    AgentsListGrouping.byRepository => _groupByRepository(agents),
    AgentsListGrouping.byStatus => _groupByStatus(agents),
  };
}

List<AgentsListSection> _groupByRepository(List<AgentSummary> agents) {
  final buckets = <String, List<AgentSummary>>{};
  for (final agent in agents) {
    final title = _repositoryTitle(agent.repoUrl);
    buckets.putIfAbsent(title, () => []).add(agent);
  }

  final titles = buckets.keys.toList(growable: false)
    ..sort((left, right) {
      if (left == _noRepositoryTitle) {
        return 1;
      }
      if (right == _noRepositoryTitle) {
        return -1;
      }
      return left.toLowerCase().compareTo(right.toLowerCase());
    });

  return [
    for (final title in titles)
      AgentsListSection(
        title: title,
        agents: List.unmodifiable(buckets[title]!),
      ),
  ];
}

List<AgentsListSection> _groupByStatus(List<AgentSummary> agents) {
  final buckets = {
    for (final title in _statusSectionOrder) title: <AgentSummary>[],
  };

  for (final agent in agents) {
    buckets[_statusTitle(agent.status)]!.add(agent);
  }

  return [
    for (final title in _statusSectionOrder)
      if (buckets[title]!.isNotEmpty)
        AgentsListSection(
          title: title,
          agents: List.unmodifiable(buckets[title]!),
        ),
  ];
}

const _noRepositoryTitle = 'No repository';
const _statusSectionOrder = ['Active', 'Finished', 'Archived', 'Other'];

String _repositoryTitle(String? repoUrl) {
  final trimmed = repoUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return _noRepositoryTitle;
  }

  final sshPathStart = trimmed.indexOf(':');
  if (!trimmed.contains('://') && sshPathStart >= 0) {
    return _ownerRepoFromPath(trimmed.substring(sshPathStart + 1)) ?? trimmed;
  }

  final uri = Uri.tryParse(trimmed);
  final path = uri == null || uri.pathSegments.isEmpty
      ? trimmed
      : uri.pathSegments.where((segment) => segment.isNotEmpty).join('/');
  return _ownerRepoFromPath(path) ?? trimmed;
}

String? _ownerRepoFromPath(String path) {
  final segments = path
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
  if (segments.length >= 2) {
    final repo = segments.last.endsWith('.git')
        ? segments.last.substring(0, segments.last.length - 4)
        : segments.last;
    return '${segments[segments.length - 2]}/$repo';
  }
  return null;
}

String _statusTitle(String status) {
  return switch (status.trim().toUpperCase()) {
    'ACTIVE' || 'CREATING' || 'RUNNING' => 'Active',
    'FINISHED' => 'Finished',
    'ARCHIVED' => 'Archived',
    _ => 'Other',
  };
}
