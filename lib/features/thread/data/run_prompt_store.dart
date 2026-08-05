import 'package:cursor/core/db/app_database.dart';

class RunPromptIndex {
  const RunPromptIndex({
    required this.byRunId,
    required this.pendingInitialPrompt,
  });

  static const empty = RunPromptIndex(byRunId: {}, pendingInitialPrompt: null);

  final Map<String, String> byRunId;
  final String? pendingInitialPrompt;
}

class RunPromptStore {
  RunPromptStore(this._dao);

  static const _pendingInitialRunId = '__pending_initial__';

  final RunPromptsDao _dao;

  Future<void> savePrompt({
    required String agentId,
    required String runId,
    required String text,
  }) {
    return _save(agentId: agentId, runId: runId, text: text);
  }

  Future<void> savePendingInitialPrompt({
    required String agentId,
    required String text,
  }) {
    return _save(agentId: agentId, runId: _pendingInitialRunId, text: text);
  }

  Future<RunPromptIndex> loadForAgent(String agentId) async {
    final rows = await _dao.getByAgentId(agentId);
    if (rows.isEmpty) {
      return RunPromptIndex.empty;
    }

    final byRunId = <String, String>{};
    String? pendingInitialPrompt;
    for (final row in rows) {
      if (row.runId == _pendingInitialRunId) {
        pendingInitialPrompt = row.content;
      } else {
        byRunId[row.runId] = row.content;
      }
    }

    return RunPromptIndex(
      byRunId: Map.unmodifiable(byRunId),
      pendingInitialPrompt: pendingInitialPrompt,
    );
  }

  Future<void> _save({
    required String agentId,
    required String runId,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return Future<void>.value();
    }

    return _dao.upsert(
      RunPromptsCompanion.insert(
        agentId: agentId,
        runId: runId,
        content: trimmed,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
