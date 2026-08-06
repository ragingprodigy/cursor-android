import 'package:cursor/features/agents/domain/agents_list_grouping.dart';
import 'package:cursor/features/agents/domain/agent_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups agents by repository with no repository last', () {
    final sections = groupAgents([
      _agent(id: 'bc-none', name: 'No repo', status: 'FINISHED'),
      _agent(
        id: 'bc-mobile',
        name: 'Mobile',
        repoUrl: 'https://github.com/acme/mobile',
        status: 'ACTIVE',
      ),
      _agent(
        id: 'bc-api',
        name: 'API',
        repoUrl: 'git@github.com:acme/api',
        status: 'ARCHIVED',
      ),
    ], AgentsListGrouping.byRepository);

    expect(sections.map((section) => section.title), [
      'acme/api',
      'acme/mobile',
      'No repository',
    ]);
    expect(sections.last.agents.single.id, 'bc-none');
  });

  test('groups agents by requested status buckets', () {
    final sections = groupAgents([
      _agent(id: 'bc-other', name: 'Other', status: 'queued'),
      _agent(id: 'bc-active', name: 'Active', status: 'RUNNING'),
      _agent(id: 'bc-finished', name: 'Finished', status: 'FINISHED'),
      _agent(id: 'bc-archived', name: 'Archived', status: 'ARCHIVED'),
    ], AgentsListGrouping.byStatus);

    expect(sections.map((section) => section.title), [
      'Active',
      'Finished',
      'Archived',
      'Other',
    ]);
    expect(sections.first.agents.single.id, 'bc-active');
  });
}

AgentSummary _agent({
  required String id,
  required String name,
  required String status,
  String? repoUrl,
}) {
  return AgentSummary(
    id: id,
    name: name,
    status: status,
    url: null,
    repoUrl: repoUrl,
    latestRunId: null,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 1),
  );
}
