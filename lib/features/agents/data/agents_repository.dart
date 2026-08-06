import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

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
  }) : this._(apiClient, database);

  AgentsRepository._(this._apiClient, this._database);

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
      final cachedById = {
        for (final agent in await _readCached()) agent.id: agent,
      };
      final agents = _parseAgentsPayload(response.data)
          .map(
            (agent) => _preserveCachedRepository(agent, cachedById[agent.id]),
          )
          .toList(growable: false);
      final cachedAt = DateTime.now().toUtc();
      await _database.agentsDao.upsertAll(
        agents.map((agent) => _companionFromSummary(agent, cachedAt)),
      );
      unawaited(_enrichMissingRepositories(agents));
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
      repoUrl: _repoUrlFromJson(json),
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

  AgentSummary _preserveCachedRepository(
    AgentSummary agent,
    AgentSummary? cached,
  ) {
    if (_blankToNull(agent.repoUrl) != null ||
        _blankToNull(cached?.repoUrl) == null) {
      return agent;
    }
    return agent.copyWith(repoUrl: cached!.repoUrl);
  }

  Future<void> _enrichMissingRepositories(List<AgentSummary> agents) async {
    final missing = agents
        .where((agent) => _blankToNull(agent.repoUrl) == null)
        .toList(growable: false);
    if (missing.isEmpty) {
      return;
    }

    for (var offset = 0; offset < missing.length; offset += 4) {
      final end = offset + 4 > missing.length ? missing.length : offset + 4;
      final chunk = missing.sublist(offset, end);
      await Future.wait(chunk.map(_tryEnrichRepository));
    }
  }

  Future<void> _tryEnrichRepository(AgentSummary agent) async {
    try {
      final encodedAgentId = Uri.encodeComponent(agent.id);
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/v1/agents/$encodedAgentId',
      );
      final detail = _summaryFromDetailPayload(response.data, fallback: agent);
      if (_blankToNull(detail.repoUrl) == null) {
        return;
      }
      await _database.agentsDao.upsertAll([
        _companionFromSummary(detail, DateTime.now().toUtc()),
      ]);
    } on AppException catch (error, stackTrace) {
      developer.log(
        'Unable to enrich agent repository.',
        name: 'AgentsRepository',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Unable to cache enriched agent repository.',
        name: 'AgentsRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  AgentSummary _summaryFromDetailPayload(
    Object? data, {
    required AgentSummary fallback,
  }) {
    final payload = _asMap(data);
    final agent = payload['agent'];
    if (agent is Map<String, dynamic>) {
      return _summaryFromJson(
        agent,
      ).copyWith(repoUrl: _repoUrlFromJson(agent) ?? fallback.repoUrl);
    }
    return _summaryFromJson(
      payload,
    ).copyWith(repoUrl: _repoUrlFromJson(payload) ?? fallback.repoUrl);
  }

  String? _repoUrlFromJson(Map<String, dynamic> json) {
    final direct = _stringAt(json, 'repoUrl') ?? _stringAt(json, 'repo_url');
    if (direct != null) {
      return direct;
    }
    final repos = json['repos'];
    if (repos is List && repos.isNotEmpty) {
      final first = repos.first;
      if (first is Map<String, dynamic>) {
        return _stringAt(first, 'url') ?? _stringAt(first, 'repoUrl');
      }
      if (first is Map) {
        final map = first.map((key, value) => MapEntry(key.toString(), value));
        return _stringAt(map, 'url') ?? _stringAt(map, 'repoUrl');
      }
    }
    return null;
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
        if (agent.repoUrl != null) 'repoUrl': agent.repoUrl,
        if (agent.latestRunId != null) 'latestRunId': agent.latestRunId,
        'createdAt': agent.createdAt.toUtc().toIso8601String(),
        'updatedAt': agent.updatedAt.toUtc().toIso8601String(),
      }),
      cachedAt: cachedAt,
    );
  }

  AgentSummary _summaryFromRow(AgentCacheRow row) {
    final json = _jsonFromCacheRow(row);
    return AgentSummary(
      id: row.id,
      name: row.name,
      status: row.status,
      url: row.url == null ? null : Uri.tryParse(row.url!),
      repoUrl: _repoUrlFromJson(json),
      latestRunId: row.latestRunId,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  Map<String, dynamic> _jsonFromCacheRow(AgentCacheRow row) {
    try {
      return _asMap(row.json);
    } on AppException {
      return const {};
    }
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
