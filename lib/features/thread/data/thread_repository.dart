import 'dart:convert';

import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
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

  @override
  List<Object?> get props {
    return [agent, runs, messages, isOffline, isStale, cachedAt];
  }
}

class ThreadRepository {
  ThreadRepository({
    required CursorApiClient apiClient,
    required AppDatabase database,
  }) : this._(apiClient, database);

  ThreadRepository._(this._apiClient, this._database);

  final CursorApiClient _apiClient;
  final AppDatabase _database;

  Stream<ThreadSnapshot> watchCache(String agentId) {
    return _database.threadSnapshotsDao.watchByAgentId(agentId).map((row) {
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
      final runs = _parseRunsPayload(runsResponse.data, agentId: agentId);
      final cachedAt = DateTime.now().toUtc();

      await _database.threadSnapshotsDao.upsert(
        ThreadSnapshotsCompanion.insert(
          agentId: agentId,
          json: jsonEncode({
            'agent': agent.toJson(),
            'runs': runs.map((run) => run.toJson()).toList(growable: false),
          }),
          cachedAt: cachedAt,
        ),
      );

      return ThreadSnapshot.fresh(agent: agent, runs: runs);
    } on NetworkException {
      return _readStaleCache(agentId, isOffline: true);
    }
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

  ThreadSnapshot _snapshotFromRow(
    ThreadSnapshotRow row, {
    required bool isStale,
    required bool isOffline,
  }) {
    try {
      final payload = _asMap(row.json, 'cached thread snapshot');
      final agentJson = payload['agent'];
      final agent = agentJson is Map
          ? _agentFromJson(_stringKeyedMap(agentJson), fallbackId: row.agentId)
          : null;
      final runs = _runsFromItems(payload['runs'], agentId: row.agentId);

      if (isStale) {
        return ThreadSnapshot.stale(
          agent: agent,
          runs: runs,
          isOffline: isOffline,
          cachedAt: row.cachedAt.toUtc(),
        );
      }
      return ThreadSnapshot.cached(
        agent: agent,
        runs: runs,
        cachedAt: row.cachedAt.toUtc(),
      );
    } on AppException {
      if (isStale) {
        return ThreadSnapshot.stale(agent: null, isOffline: isOffline);
      }
      return ThreadSnapshot.cached(agent: null);
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
