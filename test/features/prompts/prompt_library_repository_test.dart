import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/features/prompts/data/prompt_library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PromptLibraryRepository repository;

  setUp(() {
    database = AppDatabase.memory();
    repository = PromptLibraryRepository(database.savedPromptsDao);
  });

  tearDown(() async {
    await database.close();
  });

  test('upsert creates and updates prompts with normalized tags', () async {
    final created = await repository.upsert(
      title: ' Code review ',
      body: ' Review the PR carefully. ',
      notes: ' Use for adversarial reviews ',
      tags: ['Review', ' review ', 'testing'],
    );

    expect(created.title, 'Code review');
    expect(created.body, 'Review the PR carefully.');
    expect(created.notes, 'Use for adversarial reviews');
    expect(created.tags, ['Review', 'testing']);

    final updated = await repository.upsert(
      id: created.id,
      title: 'Code review',
      body: 'Updated body',
      tags: ['review'],
    );

    expect(updated.id, created.id);
    expect(updated.body, 'Updated body');
    expect(updated.createdAt.isBefore(updated.updatedAt) ||
            updated.createdAt.isAtSameMomentAs(updated.updatedAt),
        isTrue);
    expect(updated.tags, ['review']);

    final loaded = await repository.getById(created.id);
    expect(loaded?.body, 'Updated body');
  });

  test('list filters by title tags notes and body', () async {
    await repository.upsert(
      title: 'Adversarial review',
      body: 'Find bugs by severity',
      notes: 'cloud agents',
      tags: ['review', 'qa'],
    );
    await repository.upsert(
      title: 'Launch checklist',
      body: 'Ship the feature',
      tags: ['release'],
    );

    final byTag = await repository.list(query: 'qa');
    expect(byTag, hasLength(1));
    expect(byTag.single.title, 'Adversarial review');

    final byBody = await repository.list(query: 'Ship');
    expect(byBody, hasLength(1));
    expect(byBody.single.title, 'Launch checklist');
  });

  test('delete removes a prompt', () async {
    final created = await repository.upsert(
      title: 'Temp',
      body: 'Temporary body',
    );
    await repository.delete(created.id);
    expect(await repository.getById(created.id), isNull);
    expect(await repository.list(), isEmpty);
  });

  test('clearLocalCache retains saved prompts', () async {
    await repository.upsert(title: 'Keep me', body: 'Important prompt');
    await database.clearLocalCache();
    final remaining = await repository.list();
    expect(remaining, hasLength(1));
    expect(remaining.single.title, 'Keep me');
  });

  test('upsert rejects blank title or body', () async {
    expect(
      () => repository.upsert(title: ' ', body: 'body'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => repository.upsert(title: 'Title', body: '   '),
      throwsA(isA<ArgumentError>()),
    );
  });
}
