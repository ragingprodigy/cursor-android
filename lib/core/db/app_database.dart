import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

@DriftDatabase(
  tables: [Agents, ThreadSnapshots, Drafts],
  daos: [AgentsDao, ThreadSnapshotsDao, DraftsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.memory() : this(NativeDatabase.memory());

  AppDatabase.defaults() : this(driftDatabase(name: 'cursor'));

  @override
  int get schemaVersion => 1;
}
