import 'package:cursor/core/db/app_database.dart';

class RunResultStore {
  RunResultStore(this._dao);

  final RunResultsDao _dao;

  Future<void> saveResult({
    required String agentId,
    required String runId,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return Future<void>.value();
    }

    return _dao.upsert(
      RunResultsCompanion.insert(
        agentId: agentId,
        runId: runId,
        content: trimmed,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<Map<String, String>> loadForAgent(String agentId) async {
    final rows = await _dao.getByAgentId(agentId);
    if (rows.isEmpty) {
      return const {};
    }

    return Map.unmodifiable({for (final row in rows) row.runId: row.content});
  }
}
