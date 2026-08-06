import 'package:cursor/core/db/app_database.dart';
import 'package:drift/drift.dart' show Value;

/// Persists the selected follow-up model per agent.
class FollowUpModelStore {
  FollowUpModelStore(this._draftsDao);

  final DraftsDao _draftsDao;

  String _draftId(String agentId) => 'followup_model:$agentId';

  Future<String?> load(String agentId) async {
    final row = await _draftsDao.getById(_draftId(agentId));
    return _blankToNull(row?.modelId ?? row?.content);
  }

  Future<void> save(String agentId, String? modelId) {
    return _draftsDao.upsert(
      DraftsCompanion.insert(
        id: _draftId(agentId),
        content: '',
        modelId: Value(_blankToNull(modelId)),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
