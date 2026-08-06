import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/core/network/sse_client.dart';
import 'package:cursor/features/thread/data/run_prompt_store.dart';
import 'package:cursor/features/thread/data/run_result_store.dart';
import 'package:cursor/features/thread/data/thread_message_mapper.dart';
import 'package:cursor/features/thread/domain/agent_detail.dart';
import 'package:cursor/features/thread/domain/agent_run.dart';
import 'package:cursor/features/thread/domain/thread_message.dart';
import 'package:equatable/equatable.dart';

class ThreadSnapshot extends Equatable {
  ThreadSnapshot._({
    required this.agent,
    required Iterable<AgentRun> runs,
    required Iterable<ThreadMessage> messages,
    required this.isOffline,
    required this.isStale,
    this.cachedAt,
  }) : runs = List.unmodifiable(runs),
       messages = List.unmodifiable(messages);

  factory ThreadSnapshot.fresh({
    required AgentDetail? agent,
    Iterable<AgentRun> runs = const [],
    Iterable<ThreadMessage>? messages,
  }) {
    return ThreadSnapshot._(
      agent: agent,
      runs: runs,
      messages: messages ?? mapRunsToMessages(runs),
      isOffline: false,
      isStale: false,
    );
  }

  factory ThreadSnapshot.cached({
    required AgentDetail? agent,
    Iterable<AgentRun> runs = const [],
    Iterable<ThreadMessage>? messages,
    DateTime? cachedAt,
  }) {
    return ThreadSnapshot._(
      agent: agent,
      runs: runs,
      messages: messages ?? mapRunsToMessages(runs),
      isOffline: false,
      isStale: false,
      cachedAt: cachedAt,
    );
  }

  factory ThreadSnapshot.stale({
    required AgentDetail? agent,
    Iterable<AgentRun> runs = const [],
    Iterable<ThreadMessage>? messages,
    required bool isOffline,
    DateTime? cachedAt,
  }) {
    return ThreadSnapshot._(
      agent: agent,
      runs: runs,
      messages: messages ?? mapRunsToMessages(runs),
      isOffline: isOffline,
      isStale: true,
      cachedAt: cachedAt,
    );
  }

  final AgentDetail? agent;
  final List<AgentRun> runs;
  final List<ThreadMessage> messages;
  final bool isOffline;
  final bool isStale;
  final DateTime? cachedAt;

  AgentRun? get latestRun => latestAgentRun(runs);

  @override
  List<Object?> get props {
    return [agent, runs, messages, isOffline, isStale, cachedAt];
  }
}

class ThreadRepository {
  ThreadRepository({
    required CursorApiClient apiClient,
    required AppDatabase database,
    required SseClient sseClient,
    RunPromptStore? runPromptStore,
    RunResultStore? runResultStore,
    Future<void> Function()? onUnauthorized,
  }) : this._(
         apiClient,
         database,
         sseClient,
         runPromptStore,
         runResultStore,
         onUnauthorized,
       );

  ThreadRepository._(
    this._apiClient,
    this._database,
    this._sseClient,
    this._runPromptStore,
    this._runResultStore,
    this._onUnauthorized,
  );

  final CursorApiClient _apiClient;
  final AppDatabase _database;
  final SseClient _sseClient;
  final RunPromptStore? _runPromptStore;
  final RunResultStore? _runResultStore;
  final Future<void> Function()? _onUnauthorized;

  static const _runFetchConcurrency = 4;

  Stream<ThreadSnapshot> watchCache(String agentId) {
    return _database.threadSnapshotsDao.watchByAgentId(agentId).asyncMap((
      row,
    ) async {
      if (row == null) {
        return ThreadSnapshot.cached(agent: null);
      }
      return _snapshotFromRow(row, isStale: false, isOffline: false);
    });
  }

  Future<ThreadSnapshot> load(String agentId) async {
    try {
      final encodedAgentId = Uri.encodeComponent(agentId);
      final agentResponse = await _apiClient.get<Map<String, dynamic>>(
        '/v1/agents/$encodedAgentId',
      );
      final agent = _parseAgentPayload(agentResponse.data, fallbackId: agentId);
      final runsResponse = await _apiClient.get<Map<String, dynamic>>(
        '/v1/agents/$encodedAgentId/runs',
        queryParameters: const {'limit': 50},
      );
      final listedRuns = _parseRunsPayload(runsResponse.data, agentId: agentId);
      await _upsertThreadSnapshot(
        agentId: agentId,
        agent: agent,
        runs: listedRuns,
      );
      final runs = await _enrichTerminalRunResults(agentId, listedRuns);
      await _upsertThreadSnapshot(agentId: agentId, agent: agent, runs: runs);

      final conversationPrompts = await _loadConversationPrompts(agentId, runs);
      final messages = await _messagesFromRuns(
        agentId,
        runs,
        conversationPromptByRunId: conversationPrompts,
      );
      return ThreadSnapshot.fresh(agent: agent, runs: runs, messages: messages);
    } on NetworkException {
      return _readStaleCache(agentId, isOffline: true);
    }
  }

  Future<void> _upsertThreadSnapshot({
    required String agentId,
    required AgentDetail agent,
    required List<AgentRun> runs,
  }) async {
    await _database.threadSnapshotsDao.upsert(
      ThreadSnapshotsCompanion.insert(
        agentId: agentId,
        json: jsonEncode({
          'agent': agent.toJson(),
          'runs': runs.map((run) => run.toJson()).toList(growable: false),
        }),
        cachedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Streams SSE events for [runId], resuming from [lastEventId] when set.
  ///
  /// Throws [ApiException] with `statusCode == 410` when the stream has
  /// expired; callers should fall back to polling [loadRun].
  Stream<SseEvent> streamRun(
    String agentId,
    String runId, {
    String? lastEventId,
  }) {
    final encodedAgentId = Uri.encodeComponent(agentId);
    final encodedRunId = Uri.encodeComponent(runId);
    return _sseClient.stream(
      '/v1/agents/$encodedAgentId/runs/$encodedRunId/stream',
      lastEventId: lastEventId,
    );
  }

  Future<AgentRun> loadRun(String agentId, String runId) async {
    final encodedAgentId = Uri.encodeComponent(agentId);
    final encodedRunId = Uri.encodeComponent(runId);
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/v1/agents/$encodedAgentId/runs/$encodedRunId',
    );
    final run = _runFromResponse(response.data, agentId: agentId);
    await _saveRunResultIfPresent(run);
    return run;
  }

  Future<AgentRun> sendFollowUp(String agentId, String text) async {
    final encodedAgentId = Uri.encodeComponent(agentId);
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/v1/agents/$encodedAgentId/runs',
      data: {
        'prompt': {'text': text},
      },
    );
    final run = _runFromResponse(response.data, agentId: agentId);
    await _saveRunPrompt(agentId: agentId, runId: run.id, text: text);
    return run;
  }

  Future<void> cancelRun(String agentId, String runId) async {
    final encodedAgentId = Uri.encodeComponent(agentId);
    final encodedRunId = Uri.encodeComponent(runId);
    await _apiClient.post<Map<String, dynamic>>(
      '/v1/agents/$encodedAgentId/runs/$encodedRunId/cancel',
    );
  }

  Future<void> saveRunResult({
    required String agentId,
    required String runId,
    required String text,
  }) async {
    await _saveRunResult(agentId: agentId, runId: runId, text: text);
  }

  AgentRun _runFromResponse(Object? data, {required String agentId}) {
    final payload = _asMap(data, 'Cursor run response');
    final runJson = payload['run'];
    if (runJson is Map) {
      return _runFromJson(_stringKeyedMap(runJson), agentId: agentId);
    }
    return _runFromJson(payload, agentId: agentId);
  }

  Future<ThreadSnapshot> _readStaleCache(
    String agentId, {
    required bool isOffline,
  }) async {
    final row = await _database.threadSnapshotsDao.getByAgentId(agentId);
    if (row == null) {
      return ThreadSnapshot.stale(agent: null, isOffline: isOffline);
    }
    return _snapshotFromRow(row, isStale: true, isOffline: isOffline);
  }

  Future<ThreadSnapshot> _snapshotFromRow(
    ThreadSnapshotRow row, {
    required bool isStale,
    required bool isOffline,
  }) async {
    try {
      final payload = _asMap(row.json, 'cached thread snapshot');
      final agentJson = payload['agent'];
      final agent = agentJson is Map
          ? _agentFromJson(_stringKeyedMap(agentJson), fallbackId: row.agentId)
          : null;
      final cachedRuns = _runsFromItems(payload['runs'], agentId: row.agentId);
      final runs = await _mergeStoredRunResults(row.agentId, cachedRuns);
      final messages = await _messagesFromRuns(row.agentId, runs);

      if (isStale) {
        return ThreadSnapshot.stale(
          agent: agent,
          runs: runs,
          messages: messages,
          isOffline: isOffline,
          cachedAt: row.cachedAt.toUtc(),
        );
      }
      return ThreadSnapshot.cached(
        agent: agent,
        runs: runs,
        messages: messages,
        cachedAt: row.cachedAt.toUtc(),
      );
    } on AppException {
      if (isStale) {
        return ThreadSnapshot.stale(agent: null, isOffline: isOffline);
      }
      return ThreadSnapshot.cached(agent: null);
    }
  }

  Future<List<ThreadMessage>> _messagesFromRuns(
    String agentId,
    List<AgentRun> runs, {
    Map<String, String> conversationPromptByRunId = const {},
  }) async {
    final promptIndex = await _loadRunPromptIndex(agentId);
    final storedPrompts = {
      ...promptIndex.byRunId,
      ...conversationPromptByRunId,
    };
    final runsForMessages = conversationPromptByRunId.isEmpty
        ? runs
        : [
            for (final run in runs)
              if (_blankToNull(conversationPromptByRunId[run.id])
                  case final text?)
                run.copyWith(promptText: text)
              else
                run,
          ];
    return mapRunsToMessages(
      runsForMessages,
      promptTextByRunId: storedPrompts,
      pendingInitialPromptText: promptIndex.pendingInitialPrompt,
    );
  }

  Future<Map<String, String>> _loadConversationPrompts(
    String agentId,
    List<AgentRun> runs,
  ) async {
    if (runs.isEmpty) {
      return const {};
    }

    try {
      final encodedAgentId = Uri.encodeComponent(agentId);
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/v0/agents/$encodedAgentId/conversation',
      );
      final userTexts = _conversationUserTexts(response.data);
      if (userTexts.isEmpty) {
        return const {};
      }

      final sortedRuns = sortRunsByCreatedAt(runs);
      final count = userTexts.length < sortedRuns.length
          ? userTexts.length
          : sortedRuns.length;
      final prompts = <String, String>{};
      for (var index = 0; index < count; index += 1) {
        final runId = sortedRuns[index].id;
        final text = userTexts[index];
        prompts[runId] = text;
        await _saveRunPrompt(agentId: agentId, runId: runId, text: text);
      }
      return Map.unmodifiable(prompts);
    } on AppException catch (error, stackTrace) {
      developer.log(
        'Unable to load legacy conversation prompts.',
        name: 'ThreadRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return const {};
    }
  }

  List<String> _conversationUserTexts(Object? data) {
    final payload = _asMap(data, 'Cursor conversation response');
    final messages = payload['messages'];
    if (messages is! List) {
      throw const ApiException(
        'Cursor conversation response did not include messages.',
      );
    }

    return [
      for (final message in messages)
        if (message is Map)
          if (_conversationMessageText(_stringKeyedMap(message))
              case final text?)
            text,
    ];
  }

  String? _conversationMessageText(Map<String, Object?> message) {
    final type = _firstString(message, const ['type', 'role']);
    if (type != 'user_message') {
      return null;
    }
    return _firstString(message, const ['text', 'content']);
  }

  Future<RunPromptIndex> _loadRunPromptIndex(String agentId) async {
    final store = _runPromptStore;
    if (store == null) {
      return RunPromptIndex.empty;
    }

    try {
      return await store.loadForAgent(agentId);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to load saved run prompts.',
        name: 'ThreadRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return RunPromptIndex.empty;
    }
  }

  Future<Map<String, String>> _loadRunResultIndex(String agentId) async {
    final store = _runResultStore;
    if (store == null) {
      return const {};
    }

    try {
      return await store.loadForAgent(agentId);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to load saved run results.',
        name: 'ThreadRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return const {};
    }
  }

  Future<List<AgentRun>> _enrichTerminalRunResults(
    String agentId,
    List<AgentRun> listedRuns,
  ) async {
    final storedRuns = await _mergeStoredRunResults(agentId, listedRuns);
    final missing = storedRuns
        .where((run) => !run.isActive && _blankToNull(run.resultText) == null)
        .toList(growable: false);
    if (missing.isEmpty) {
      return storedRuns;
    }

    final fetchedByRunId = <String, AgentRun>{};
    for (
      var offset = 0;
      offset < missing.length;
      offset += _runFetchConcurrency
    ) {
      final end = offset + _runFetchConcurrency > missing.length
          ? missing.length
          : offset + _runFetchConcurrency;
      final chunk = missing.sublist(offset, end);
      final fetched = await Future.wait(
        chunk.map((run) => _tryFetchRunResult(agentId, run.id)),
      );
      for (final run in fetched.whereType<AgentRun>()) {
        fetchedByRunId[run.id] = run;
      }
    }

    if (fetchedByRunId.isEmpty) {
      return storedRuns;
    }

    return [for (final run in storedRuns) fetchedByRunId[run.id] ?? run];
  }

  Future<AgentRun?> _tryFetchRunResult(String agentId, String runId) async {
    try {
      final run = await loadRun(agentId, runId);
      return _blankToNull(run.resultText) == null ? null : run;
    } on UnauthorizedException catch (error, stackTrace) {
      developer.log(
        'Unable to fetch terminal run result because authorization failed.',
        name: 'ThreadRepository',
        error: error,
        stackTrace: stackTrace,
      );
      await _onUnauthorized?.call();
      return null;
    } on RateLimitedException catch (error, stackTrace) {
      developer.log(
        'Unable to fetch terminal run result because the API is rate limited.',
        name: 'ThreadRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } on AppException catch (error, stackTrace) {
      developer.log(
        'Unable to fetch terminal run result.',
        name: 'ThreadRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<List<AgentRun>> _mergeStoredRunResults(
    String agentId,
    List<AgentRun> runs,
  ) async {
    final resultIndex = await _loadRunResultIndex(agentId);
    if (resultIndex.isEmpty) {
      return runs;
    }
    return [
      for (final run in runs)
        if (_blankToNull(run.resultText) == null &&
            _blankToNull(resultIndex[run.id]) != null)
          run.copyWith(resultText: resultIndex[run.id])
        else
          run,
    ];
  }

  Future<void> _saveRunPrompt({
    required String agentId,
    required String runId,
    required String text,
  }) async {
    final store = _runPromptStore;
    if (store == null) {
      return;
    }

    try {
      await store.savePrompt(agentId: agentId, runId: runId, text: text);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to save run prompt.',
        name: 'ThreadRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveRunResultIfPresent(AgentRun run) async {
    final resultText = _blankToNull(run.resultText);
    final agentId = run.agentId;
    if (resultText == null || agentId == null) {
      return;
    }
    await _saveRunResult(agentId: agentId, runId: run.id, text: resultText);
  }

  Future<void> _saveRunResult({
    required String agentId,
    required String runId,
    required String text,
  }) async {
    final store = _runResultStore;
    if (store == null) {
      return;
    }

    try {
      await store.saveResult(agentId: agentId, runId: runId, text: text);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to save run result.',
        name: 'ThreadRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  AgentDetail _parseAgentPayload(Object? data, {required String fallbackId}) {
    final payload = _asMap(data, 'Cursor agent response');
    final agent = payload['agent'];
    if (agent is Map) {
      return _agentFromJson(_stringKeyedMap(agent), fallbackId: fallbackId);
    }
    return _agentFromJson(payload, fallbackId: fallbackId);
  }

  AgentDetail _agentFromJson(
    Map<String, Object?> json, {
    required String fallbackId,
  }) {
    final now = DateTime.now().toUtc();
    final id =
        _firstString(json, const ['id', 'agentId', 'agent_id']) ?? fallbackId;
    final createdAt = _dateAt(json, 'createdAt', 'created_at') ?? now;

    return AgentDetail(
      id: id,
      name: _firstString(json, const ['name', 'title']) ?? 'Agent $id',
      status: _firstString(json, const ['status', 'state']) ?? 'unknown',
      url: _uriAt(json, 'url'),
      repoUrl: _repoUrlFromJson(json),
      latestRunId: _firstString(json, const ['latestRunId', 'latest_run_id']),
      createdAt: createdAt,
      updatedAt: _dateAt(json, 'updatedAt', 'updated_at') ?? createdAt,
    );
  }

  List<AgentRun> _parseRunsPayload(Object? data, {required String agentId}) {
    final items = _itemsFromPayload(data, 'runs');
    return _runsFromItems(items, agentId: agentId);
  }

  List<AgentRun> _runsFromItems(Object? value, {required String agentId}) {
    if (value is! List) {
      throw const ApiException('Cursor runs response did not include items.');
    }

    return value
        .map((item) {
          if (item is! Map) {
            throw const ApiException('Cursor run item was invalid.');
          }
          return _runFromJson(_stringKeyedMap(item), agentId: agentId);
        })
        .toList(growable: false);
  }

  AgentRun _runFromJson(Map<String, Object?> json, {required String agentId}) {
    final now = DateTime.now().toUtc();
    final id = _firstString(json, const ['id', 'runId', 'run_id']);
    if (id == null) {
      throw const ApiException('Cursor run item was missing id.');
    }
    final createdAt = _dateAt(json, 'createdAt', 'created_at') ?? now;
    final payload = json['payload'];

    return AgentRun(
      id: id,
      agentId: _firstString(json, const ['agentId', 'agent_id']) ?? agentId,
      status: _firstString(json, const ['status', 'state']) ?? 'unknown',
      promptText: _promptTextFromJson(json),
      resultText: _resultTextFromJson(json),
      createdAt: createdAt,
      updatedAt: _dateAt(json, 'updatedAt', 'updated_at'),
      payload: payload is Map ? _stringKeyedMap(payload) : json,
    );
  }

  Object? _itemsFromPayload(Object? data, String alternateKey) {
    if (data is List) {
      return data;
    }
    final payload = _asMap(data, 'Cursor runs response');
    return payload['items'] ?? payload[alternateKey];
  }

  Map<String, Object?> _asMap(Object? data, String subject) {
    if (data is Map) {
      return _stringKeyedMap(data);
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return _stringKeyedMap(decoded);
        }
      } on FormatException {
        throw ApiException('$subject was not valid JSON.');
      }
    }
    throw ApiException('$subject was invalid.');
  }

  Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> value) {
    return value.map(
      (key, value) => MapEntry(key.toString(), _jsonValue(value)),
    );
  }

  Object? _jsonValue(Object? value) {
    if (value is Map) {
      return _stringKeyedMap(value);
    }
    if (value is List) {
      return value.map(_jsonValue).toList(growable: false);
    }
    return value;
  }

  String? _promptTextFromJson(Map<String, Object?> json) {
    return _firstString(json, const ['promptText', 'prompt_text']) ??
        _nestedText(json['prompt']) ??
        _nestedText(json['input']) ??
        _nestedPromptText(json['request']);
  }

  String? _resultTextFromJson(Map<String, Object?> json) {
    return _firstString(json, const [
          'resultText',
          'result_text',
          'summary',
          'finalOutput',
          'final_output',
        ]) ??
        _nestedText(json['result']) ??
        _nestedText(json['response']) ??
        _nestedText(json['output']);
  }

  String? _nestedPromptText(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = _stringKeyedMap(value);
    return _nestedText(map['prompt']) ?? _firstString(map, const ['prompt']);
  }

  String? _nestedText(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is Map) {
      final map = _stringKeyedMap(value);
      return _firstString(map, const [
        'text',
        'content',
        'summary',
        'output',
        'message',
      ]);
    }
    return null;
  }

  String? _firstString(Map<String, Object?> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  Uri? _uriAt(Map<String, Object?> json, String key) {
    final value = _firstString(json, [key]);
    if (value == null) {
      return null;
    }
    return Uri.tryParse(value);
  }

  String? _repoUrlFromJson(Map<String, Object?> json) {
    final direct = _firstString(json, const ['repoUrl', 'repo_url']);
    if (direct != null) {
      return direct;
    }
    final repos = json['repos'];
    if (repos is List && repos.isNotEmpty) {
      final first = repos.first;
      if (first is Map) {
        return _firstString(_stringKeyedMap(first), const ['url', 'repoUrl']);
      }
    }
    return null;
  }

  DateTime? _dateAt(
    Map<String, Object?> json,
    String camelCase,
    String snakeCase,
  ) {
    final value = _firstString(json, [camelCase, snakeCase]);
    if (value == null) {
      return null;
    }
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      throw ApiException('Cursor thread item had invalid $camelCase.');
    }
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
