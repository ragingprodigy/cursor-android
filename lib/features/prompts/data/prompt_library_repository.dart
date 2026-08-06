import 'dart:math';

import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/features/prompts/domain/saved_prompt.dart';
import 'package:drift/drift.dart';

class PromptLibraryRepository {
  PromptLibraryRepository(this._dao);

  final SavedPromptsDao _dao;

  Future<List<SavedPrompt>> list({String query = ''}) async {
    final rows = await _dao.getAll();
    final prompts = rows.map(_fromRow).toList(growable: false);
    if (query.trim().isEmpty) {
      return prompts;
    }
    return prompts
        .where((prompt) => prompt.matchesQuery(query))
        .toList(growable: false);
  }

  Stream<List<SavedPrompt>> watchAll() {
    return _dao.watchAll().map(
      (rows) => rows.map(_fromRow).toList(growable: false),
    );
  }

  Future<SavedPrompt?> getById(String id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _fromRow(row);
  }

  Future<SavedPrompt> upsert({
    String? id,
    required String title,
    required String body,
    String? notes,
    List<String> tags = const [],
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Title is required.');
    }
    if (trimmedBody.isEmpty) {
      throw ArgumentError('Body is required.');
    }

    final now = DateTime.now().toUtc();
    final existingId = id?.trim();
    final existing = existingId == null || existingId.isEmpty
        ? null
        : await _dao.getById(existingId);
    final promptId = existing?.id ?? _newId();
    final createdAt = existing?.createdAt ?? now;
    final normalizedTags = _normalizeTags(tags);
    final companion = SavedPromptsCompanion(
      id: Value(promptId),
      title: Value(trimmedTitle),
      body: Value(trimmedBody),
      notes: Value(_blankToNull(notes)),
      tags: Value(_tagsToStorage(normalizedTags)),
      createdAt: Value(createdAt),
      updatedAt: Value(now),
    );
    await _dao.upsert(companion);
    return SavedPrompt(
      id: promptId,
      title: trimmedTitle,
      body: trimmedBody,
      notes: _blankToNull(notes),
      tags: normalizedTags,
      createdAt: createdAt,
      updatedAt: now,
    );
  }

  Future<void> delete(String id) {
    return _dao.deleteById(id);
  }

  SavedPrompt _fromRow(SavedPromptRow row) {
    return SavedPrompt(
      id: row.id,
      title: row.title,
      body: row.body,
      notes: _blankToNull(row.notes),
      tags: _tagsFromStorage(row.tags),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}

String _newId() {
  final random = Random.secure().nextInt(1 << 32).toRadixString(16);
  return 'prompt-${DateTime.now().toUtc().microsecondsSinceEpoch}-$random';
}

List<String> _normalizeTags(Iterable<String> tags) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final raw in tags) {
    for (final part in raw.split(',')) {
      final tag = part.trim();
      if (tag.isEmpty) {
        continue;
      }
      final key = tag.toLowerCase();
      if (seen.add(key)) {
        normalized.add(tag);
      }
    }
  }
  return normalized;
}

String _tagsToStorage(List<String> tags) => tags.join(', ');

List<String> _tagsFromStorage(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const [];
  }
  return _normalizeTags(value.split(','));
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
