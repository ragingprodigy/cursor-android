import 'package:cursor/core/db/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:equatable/equatable.dart';

class LaunchDraft extends Equatable {
  const LaunchDraft({
    required this.prompt,
    this.repoUrl,
    this.startingRef,
    this.modelId,
  });

  static const empty = LaunchDraft(prompt: '');

  final String prompt;
  final String? repoUrl;
  final String? startingRef;
  final String? modelId;

  LaunchDraft copyWith({
    String? prompt,
    Object? repoUrl = _sentinel,
    Object? startingRef = _sentinel,
    Object? modelId = _sentinel,
  }) {
    return LaunchDraft(
      prompt: prompt ?? this.prompt,
      repoUrl: repoUrl == _sentinel ? this.repoUrl : repoUrl as String?,
      startingRef: startingRef == _sentinel
          ? this.startingRef
          : startingRef as String?,
      modelId: modelId == _sentinel ? this.modelId : modelId as String?,
    );
  }

  @override
  List<Object?> get props => [prompt, repoUrl, startingRef, modelId];
}

class LaunchDraftStore {
  LaunchDraftStore(this._draftsDao);

  static const draftId = 'launch';

  final DraftsDao _draftsDao;

  Future<LaunchDraft> load() async {
    final row = await _draftsDao.getById(draftId);
    if (row == null) {
      return LaunchDraft.empty;
    }
    return LaunchDraft(
      prompt: row.content,
      repoUrl: row.repoUrl,
      startingRef: row.startingRef,
      modelId: row.modelId,
    );
  }

  Future<void> save(LaunchDraft draft) {
    return _draftsDao.upsert(
      DraftsCompanion.insert(
        id: draftId,
        content: draft.prompt,
        repoUrl: Value(_blankToNull(draft.repoUrl)),
        startingRef: Value(_blankToNull(draft.startingRef)),
        modelId: Value(_blankToNull(draft.modelId)),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> clear() {
    return _draftsDao.deleteById(draftId);
  }
}

const _sentinel = Object();

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
