import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;

part 'app_database.g.dart';

@DataClassName('AgentCacheRow')
class Agents extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get status => text()();
  TextColumn get url => text().nullable()();
  TextColumn get latestRunId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get json => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ThreadSnapshotRow')
class ThreadSnapshots extends Table {
  TextColumn get agentId => text()();
  TextColumn get json => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {agentId};
}

@DataClassName('DraftRow')
class Drafts extends Table {
  TextColumn get id => text()();
  TextColumn get content => text().named('text')();
  TextColumn get repoUrl => text().nullable()();
  TextColumn get startingRef => text().nullable()();
  TextColumn get modelId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RunPromptRow')
class RunPrompts extends Table {
  TextColumn get agentId => text()();
  TextColumn get runId => text()();
  TextColumn get content => text().named('text')();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {agentId, runId};
}

@DataClassName('RunResultRow')
class RunResults extends Table {
  TextColumn get agentId => text()();
  TextColumn get runId => text()();
  TextColumn get content => text().named('text')();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {agentId, runId};
}

@DataClassName('SavedPromptRow')
class SavedPrompts extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftAccessor(tables: [Agents])
class AgentsDao extends DatabaseAccessor<AppDatabase> with _$AgentsDaoMixin {
  AgentsDao(super.db);

  Future<List<AgentCacheRow>> getAll() {
    return (select(agents)..orderBy([
          (agent) => OrderingTerm.desc(agent.updatedAt),
          (agent) => OrderingTerm.desc(agent.cachedAt),
        ]))
        .get();
  }

  Stream<List<AgentCacheRow>> watchAll() {
    return (select(agents)..orderBy([
          (agent) => OrderingTerm.desc(agent.updatedAt),
          (agent) => OrderingTerm.desc(agent.cachedAt),
        ]))
        .watch();
  }

  Future<AgentCacheRow?> getById(String id) {
    return (select(
      agents,
    )..where((agent) => agent.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertAll(Iterable<AgentsCompanion> rows) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(agents, rows);
    });
  }

  Future<int> deleteById(String id) {
    return (delete(agents)..where((agent) => agent.id.equals(id))).go();
  }
}

@DriftAccessor(tables: [ThreadSnapshots])
class ThreadSnapshotsDao extends DatabaseAccessor<AppDatabase>
    with _$ThreadSnapshotsDaoMixin {
  ThreadSnapshotsDao(super.db);

  Future<ThreadSnapshotRow?> getByAgentId(String agentId) {
    return (select(
      threadSnapshots,
    )..where((snapshot) => snapshot.agentId.equals(agentId))).getSingleOrNull();
  }

  Stream<ThreadSnapshotRow?> watchByAgentId(String agentId) {
    return (select(threadSnapshots)
          ..where((snapshot) => snapshot.agentId.equals(agentId)))
        .watchSingleOrNull();
  }

  Future<void> upsert(ThreadSnapshotsCompanion row) {
    return into(threadSnapshots).insertOnConflictUpdate(row);
  }

  Future<int> deleteByAgentId(String agentId) {
    return (delete(
      threadSnapshots,
    )..where((snapshot) => snapshot.agentId.equals(agentId))).go();
  }
}

@DriftAccessor(tables: [Drafts])
class DraftsDao extends DatabaseAccessor<AppDatabase> with _$DraftsDaoMixin {
  DraftsDao(super.db);

  Future<List<DraftRow>> getAll() {
    return (select(
      drafts,
    )..orderBy([(draft) => OrderingTerm.desc(draft.updatedAt)])).get();
  }

  Future<DraftRow?> getById(String id) {
    return (select(
      drafts,
    )..where((draft) => draft.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(DraftsCompanion row) {
    return into(drafts).insertOnConflictUpdate(row);
  }

  Future<int> deleteById(String id) {
    return (delete(drafts)..where((draft) => draft.id.equals(id))).go();
  }
}

@DriftAccessor(tables: [RunPrompts])
class RunPromptsDao extends DatabaseAccessor<AppDatabase>
    with _$RunPromptsDaoMixin {
  RunPromptsDao(super.db);

  Future<List<RunPromptRow>> getByAgentId(String agentId) {
    return (select(runPrompts)
          ..where((prompt) => prompt.agentId.equals(agentId))
          ..orderBy([(prompt) => OrderingTerm.asc(prompt.createdAt)]))
        .get();
  }

  Future<RunPromptRow?> getByRunId(String agentId, String runId) {
    return (select(runPrompts)..where(
          (prompt) =>
              prompt.agentId.equals(agentId) & prompt.runId.equals(runId),
        ))
        .getSingleOrNull();
  }

  Future<void> upsert(RunPromptsCompanion row) {
    return into(runPrompts).insertOnConflictUpdate(row);
  }

  Future<int> deleteByRunId(String agentId, String runId) {
    return (delete(runPrompts)..where(
          (prompt) =>
              prompt.agentId.equals(agentId) & prompt.runId.equals(runId),
        ))
        .go();
  }

  Future<int> deleteByAgentId(String agentId) {
    return (delete(
      runPrompts,
    )..where((prompt) => prompt.agentId.equals(agentId))).go();
  }
}

@DriftAccessor(tables: [RunResults])
class RunResultsDao extends DatabaseAccessor<AppDatabase>
    with _$RunResultsDaoMixin {
  RunResultsDao(super.db);

  Future<List<RunResultRow>> getByAgentId(String agentId) {
    return (select(runResults)
          ..where((result) => result.agentId.equals(agentId))
          ..orderBy([(result) => OrderingTerm.asc(result.createdAt)]))
        .get();
  }

  Future<RunResultRow?> getByRunId(String agentId, String runId) {
    return (select(runResults)..where(
          (result) =>
              result.agentId.equals(agentId) & result.runId.equals(runId),
        ))
        .getSingleOrNull();
  }

  Future<void> upsert(RunResultsCompanion row) {
    return into(runResults).insertOnConflictUpdate(row);
  }

  Future<int> deleteByAgentId(String agentId) {
    return (delete(
      runResults,
    )..where((result) => result.agentId.equals(agentId))).go();
  }
}

@DriftAccessor(tables: [SavedPrompts])
class SavedPromptsDao extends DatabaseAccessor<AppDatabase>
    with _$SavedPromptsDaoMixin {
  SavedPromptsDao(super.db);

  Future<List<SavedPromptRow>> getAll() {
    return (select(savedPrompts)..orderBy([
          (prompt) => OrderingTerm.desc(prompt.updatedAt),
          (prompt) => OrderingTerm.asc(prompt.title),
        ]))
        .get();
  }

  Stream<List<SavedPromptRow>> watchAll() {
    return (select(savedPrompts)..orderBy([
          (prompt) => OrderingTerm.desc(prompt.updatedAt),
          (prompt) => OrderingTerm.asc(prompt.title),
        ]))
        .watch();
  }

  Future<SavedPromptRow?> getById(String id) {
    return (select(
      savedPrompts,
    )..where((prompt) => prompt.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(SavedPromptsCompanion row) {
    return into(savedPrompts).insertOnConflictUpdate(row);
  }

  Future<int> deleteById(String id) {
    return (delete(savedPrompts)..where((prompt) => prompt.id.equals(id))).go();
  }
}

@DriftDatabase(
  tables: [
    Agents,
    ThreadSnapshots,
    Drafts,
    RunPrompts,
    RunResults,
    SavedPrompts,
  ],
  daos: [
    AgentsDao,
    ThreadSnapshotsDao,
    DraftsDao,
    RunPromptsDao,
    RunResultsDao,
    SavedPromptsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.memory() : this(_openMemoryDatabase());

  AppDatabase.defaults() : this(_openDefaultDatabase());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(runPrompts);
        }
        if (from < 3) {
          await migrator.createTable(runResults);
        }
        if (from < 4) {
          await migrator.createTable(savedPrompts);
        }
      },
    );
  }

  Future<void> clearLocalCache() {
    return batch((batch) {
      batch.deleteAll(agents);
      batch.deleteAll(threadSnapshots);
      batch.deleteAll(drafts);
      batch.deleteAll(runPrompts);
      batch.deleteAll(runResults);
      // Saved prompts are user content and intentionally retained.
    });
  }
}

bool _linuxSqliteOverrideInstalled = false;

QueryExecutor _openMemoryDatabase() {
  _installLinuxSqliteFallback();
  return NativeDatabase.memory();
}

QueryExecutor _openDefaultDatabase() {
  _installLinuxSqliteFallback();
  return driftDatabase(name: 'cursor');
}

void _installLinuxSqliteFallback() {
  if (!Platform.isLinux || _linuxSqliteOverrideInstalled) {
    return;
  }

  sqlite3_open.open.overrideFor(sqlite3_open.OperatingSystem.linux, () {
    try {
      return DynamicLibrary.open('libsqlite3.so');
    } on ArgumentError {
      return DynamicLibrary.open('libsqlite3.so.0');
    }
  });
  _linuxSqliteOverrideInstalled = true;
}
