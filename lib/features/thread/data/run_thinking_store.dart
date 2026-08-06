import 'package:cursor/core/db/app_database.dart';

/// Stores streamed thinking text per agent run for local thread refreshes.
class RunThinkingStore {
  RunThinkingStore(this._draftsDao);

  final DraftsDao _draftsDao;

  String _draftId({required String agentId, required String runId}) {
    return 'thinking:$agentId:$runId';
  }

  String _prefix(String agentId) => 'thinking:$agentId:';

  Future<Map<String, String>> loadForAgent(String agentId) async {
    final rows = await _draftsDao.getAll();
    final prefix = _prefix(agentId);
    return {
      for (final row in rows)
        if (row.id.startsWith(prefix) && row.content.trim().isNotEmpty)
          row.id.substring(prefix.length): row.content.trim(),
    };
  }

  Future<void> saveThinking({
    required String agentId,
    required String runId,
    required String text,
  }) {
    return _draftsDao.upsert(
      DraftsCompanion.insert(
        id: _draftId(agentId: agentId, runId: runId),
        content: text,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
