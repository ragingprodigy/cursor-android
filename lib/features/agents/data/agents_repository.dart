import 'dart:convert';

import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/features/agents/domain/agent_summary.dart';
import 'package:drift/drift.dart' show Value;
import 'package:equatable/equatable.dart';

class AgentsSnapshot extends Equatable {
  AgentsSnapshot._({
    required Iterable<AgentSummary> agents,
    required this.isOffline,
    required this.isStale,
  }) : agents = List.unmodifiable(agents);

  AgentsSnapshot.fresh(Iterable<AgentSummary> agents)
    : this._(agents: agents, isOffline: false, isStale: false);

  AgentsSnapshot.cached(Iterable<AgentSummary> agents)
    : this._(agents: agents, isOffline: false, isStale: false);

  AgentsSnapshot.stale(Iterable<AgentSummary> agents, {required bool isOffline})
    : this._(agents: agents, isOffline: isOffline, isStale: true);

  final List<AgentSummary> agents;
  final bool isOffline;
  final bool isStale;

  @override
  List<Object?> get props => [agents, isOffline, isStale];
}

class AgentsRepository {
  AgentsRepository({
    required CursorApiClient apiClient,
    required AppDatabase database,
  }) : _apiClient = apiClient,
       _database = database;

  final CursorApiClient _apiClient;
  final AppDatabase _database;

  Stream<AgentsSnapshot> watchCached() {
    return _database.agentsDao.watchAll().map((rows) {
      return AgentsSnapshot.cached(rows.map(_summaryFromRow));
    });
  }

  Future<AgentsSnapshot> refresh() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/v1/agents',
        queryParameters: const {'limit': 50},
      );
      final agents = _parseAgentsPayload(response.data);
      final cachedAt = DateTime.now().toUtc();
      await _database.agentsDao.upsertAll(
        agents.map((agent) => _companionFromSummary(agent, cachedAt)),
      );
      return AgentsSnapshot.fresh(await _readCached());
    } on NetworkException {
      return AgentsSnapshot.stale(await _readCached(), isOffline: true);
    }
  }

  Future<List<AgentSummary>> _readCached() async {
    final rows = await _database.agentsDao.getAll();
    return rows.map(_summaryFromRow).toList(growable: false);
  }

  List<AgentSummary> _parseAgentsPayload(Object? data) {
    final payload = _asMap(data);
    final items = payload['items'];
    if (items is! List) {
      throw const ApiException('Cursor agents response did not include items.');
    }

    return items
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const ApiException(
              'Cursor agents response item was invalid.',
            );
          }
          return _summaryFromJson(item);
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } on FormatException {
        throw const ApiException('Cursor agents response was not valid JSON.');
      }
    }
    throw const ApiException('Cursor agents response was invalid.');
  }

  AgentSummary _summaryFromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    final id = _requiredString(json, 'id');
    final name = _stringAt(json, 'name') ?? 'Agent $id';
    final createdAt = _dateAt(json, 'createdAt', 'created_at') ?? now;
    final updatedAt = _dateAt(json, 'updatedAt', 'updated_at') ?? createdAt;

    return AgentSummary(
      id: id,
      name: name,
      status: _stringAt(json, 'status') ?? 'unknown',
      url: _uriAt(json, 'url'),
      latestRunId:
          _stringAt(json, 'latestRunId') ?? _stringAt(json, 'latest_run_id'),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = _stringAt(json, key);
    if (value == null) {
      throw ApiException('Cursor agent item was missing $key.');
    }
    return value;
  }

  String? _stringAt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  Uri? _uriAt(Map<String, dynamic> json, String key) {
    final value = _stringAt(json, key);
    if (value == null) {
      return null;
    }
    return Uri.tryParse(value);
  }

  DateTime? _dateAt(
    Map<String, dynamic> json,
    String camelCase,
    String snakeCase,
  ) {
    final value = _stringAt(json, camelCase) ?? _stringAt(json, snakeCase);
    if (value == null) {
      return null;
    }
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      throw ApiException('Cursor agent item had invalid $camelCase.');
    }
  }

  AgentsCompanion _companionFromSummary(AgentSummary agent, DateTime cachedAt) {
    return AgentsCompanion.insert(
      id: agent.id,
      name: agent.name,
      status: agent.status,
      url: Value(agent.url?.toString()),
      latestRunId: Value(agent.latestRunId),
      createdAt: agent.createdAt,
      updatedAt: agent.updatedAt,
      json: jsonEncode({
        'id': agent.id,
        'name': agent.name,
        'status': agent.status,
        if (agent.url != null) 'url': agent.url.toString(),
        if (agent.latestRunId != null) 'latestRunId': agent.latestRunId,
        'createdAt': agent.createdAt.toUtc().toIso8601String(),
        'updatedAt': agent.updatedAt.toUtc().toIso8601String(),
      }),
      cachedAt: cachedAt,
    );
  }

  AgentSummary _summaryFromRow(AgentCacheRow row) {
    return AgentSummary(
      id: row.id,
      name: row.name,
      status: row.status,
      url: row.url == null ? null : Uri.tryParse(row.url!),
      latestRunId: row.latestRunId,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}
