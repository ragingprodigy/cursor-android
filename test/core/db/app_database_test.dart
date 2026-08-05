import 'package:cursor/core/db/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('upserts agents and reads newest-first cache', () async {
    final olderCreated = DateTime.utc(2026, 1, 1);
    final newerCreated = DateTime.utc(2026, 1, 2);
    final initialCachedAt = DateTime.utc(2026, 1, 3);

    await db.agentsDao.upsertAll([
      AgentsCompanion.insert(
        id: 'bc-2',
        name: 'Older agent',
        status: 'completed',
        url: const Value('https://cursor.com/agents/bc-2'),
        latestRunId: const Value('run-2'),
        createdAt: olderCreated,
        updatedAt: DateTime.utc(2026, 1, 4),
        json: '{"id":"bc-2"}',
        cachedAt: initialCachedAt,
      ),
      AgentsCompanion.insert(
        id: 'bc-1',
        name: 'Newer agent',
        status: 'running',
        url: const Value('https://cursor.com/agents/bc-1'),
        latestRunId: const Value('run-1'),
        createdAt: newerCreated,
        updatedAt: DateTime.utc(2026, 1, 5),
        json: '{"id":"bc-1"}',
        cachedAt: initialCachedAt,
      ),
    ]);

    await db.agentsDao.upsertAll([
      AgentsCompanion.insert(
        id: 'bc-2',
        name: 'Older agent renamed',
        status: 'failed',
        url: const Value('https://cursor.com/agents/bc-2'),
        latestRunId: const Value('run-3'),
        createdAt: olderCreated,
        updatedAt: DateTime.utc(2026, 1, 6),
        json: '{"id":"bc-2","status":"failed"}',
        cachedAt: DateTime.utc(2026, 1, 7),
      ),
    ]);

    final rows = await db.agentsDao.getAll();

    expect(rows, hasLength(2));
    expect(rows.first.id, 'bc-2');
    expect(rows.first.name, 'Older agent renamed');
    expect(rows.first.status, 'failed');
    expect(rows.first.latestRunId, 'run-3');
    expect(rows.first.json, '{"id":"bc-2","status":"failed"}');
  });

  test('upserts and reads thread snapshots by agent id', () async {
    await db.threadSnapshotsDao.upsert(
      ThreadSnapshotsCompanion.insert(
        agentId: 'bc-1',
        json: '{"messages":[]}',
        cachedAt: DateTime.utc(2026, 2, 1),
      ),
    );

    await db.threadSnapshotsDao.upsert(
      ThreadSnapshotsCompanion.insert(
        agentId: 'bc-1',
        json: '{"messages":[{"text":"hello"}]}',
        cachedAt: DateTime.utc(2026, 2, 2),
      ),
    );

    final row = await db.threadSnapshotsDao.getByAgentId('bc-1');

    expect(row, isNotNull);
    expect(row!.json, '{"messages":[{"text":"hello"}]}');
    expect(row.cachedAt.toUtc(), DateTime.utc(2026, 2, 2));
  });

  test('saves, reads, and deletes drafts', () async {
    await db.draftsDao.upsert(
      DraftsCompanion.insert(
        id: 'launch',
        content: 'Build the Android app',
        repoUrl: const Value('https://github.com/acme/app'),
        startingRef: const Value('main'),
        modelId: const Value('gpt-5.5'),
        updatedAt: DateTime.utc(2026, 3, 1),
      ),
    );

    await db.draftsDao.upsert(
      DraftsCompanion.insert(
        id: 'followup:bc-1',
        content: 'Ship the follow-up',
        repoUrl: const Value.absent(),
        startingRef: const Value.absent(),
        modelId: const Value.absent(),
        updatedAt: DateTime.utc(2026, 3, 2),
      ),
    );

    final launchDraft = await db.draftsDao.getById('launch');
    final drafts = await db.draftsDao.getAll();

    expect(launchDraft!.repoUrl, 'https://github.com/acme/app');
    expect(drafts.map((draft) => draft.id), ['followup:bc-1', 'launch']);

    await db.draftsDao.deleteById('launch');

    expect(await db.draftsDao.getById('launch'), isNull);
  });

  test('upserts and reads run prompts by agent id', () async {
    await db.runPromptsDao.upsert(
      RunPromptsCompanion.insert(
        agentId: 'bc-1',
        runId: 'run-1',
        content: 'Build the Android app',
        createdAt: DateTime.utc(2026, 3, 3),
      ),
    );

    await db.runPromptsDao.upsert(
      RunPromptsCompanion.insert(
        agentId: 'bc-1',
        runId: 'run-1',
        content: 'Build the Android app again',
        createdAt: DateTime.utc(2026, 3, 4),
      ),
    );

    final row = await db.runPromptsDao.getByRunId('bc-1', 'run-1');
    final rows = await db.runPromptsDao.getByAgentId('bc-1');

    expect(row, isNotNull);
    expect(row!.content, 'Build the Android app again');
    expect(rows.map((prompt) => prompt.runId), ['run-1']);
  });

  test('clears all local cache tables', () async {
    await db.agentsDao.upsertAll([
      AgentsCompanion.insert(
        id: 'bc-cache',
        name: 'Cached agent',
        status: 'running',
        url: const Value('https://cursor.com/agents/bc-cache'),
        latestRunId: const Value('run-cache'),
        createdAt: DateTime.utc(2026, 4, 1),
        updatedAt: DateTime.utc(2026, 4, 2),
        json: '{"id":"bc-cache"}',
        cachedAt: DateTime.utc(2026, 4, 3),
      ),
    ]);
    await db.threadSnapshotsDao.upsert(
      ThreadSnapshotsCompanion.insert(
        agentId: 'bc-cache',
        json: '{"runs":[]}',
        cachedAt: DateTime.utc(2026, 4, 4),
      ),
    );
    await db.draftsDao.upsert(
      DraftsCompanion.insert(
        id: 'followup:bc-cache',
        content: 'Keep going',
        repoUrl: const Value.absent(),
        startingRef: const Value.absent(),
        modelId: const Value.absent(),
        updatedAt: DateTime.utc(2026, 4, 5),
      ),
    );
    await db.runPromptsDao.upsert(
      RunPromptsCompanion.insert(
        agentId: 'bc-cache',
        runId: 'run-cache',
        content: 'Cached prompt',
        createdAt: DateTime.utc(2026, 4, 6),
      ),
    );

    await db.clearLocalCache();

    expect(await db.agentsDao.getAll(), isEmpty);
    expect(await db.threadSnapshotsDao.getByAgentId('bc-cache'), isNull);
    expect(await db.draftsDao.getAll(), isEmpty);
    expect(await db.runPromptsDao.getByAgentId('bc-cache'), isEmpty);
  });
}
