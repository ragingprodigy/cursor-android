import 'package:cursor/core/db/app_database.dart';

/// Persists per-agent follow-up composer drafts under id `followup:<agentId>`
/// so unsent text survives navigation and process death.
class FollowUpDraftStore {
  FollowUpDraftStore(this._draftsDao);

  final DraftsDao _draftsDao;

  String _draftId(String agentId) => 'followup:$agentId';

  Future<String> load(String agentId) async {
    final row = await _draftsDao.getById(_draftId(agentId));
    return row?.content ?? '';
  }

  Future<void> save(String agentId, String text) {
    return _draftsDao.upsert(
      DraftsCompanion.insert(
        id: _draftId(agentId),
        content: text,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> clear(String agentId) {
    return _draftsDao.deleteById(_draftId(agentId));
  }
}
