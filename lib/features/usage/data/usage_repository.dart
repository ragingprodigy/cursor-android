import 'dart:developer' as developer;

import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/features/thread/domain/agent_usage.dart';
import 'package:cursor/features/usage/domain/usage_report.dart';

class UsageRepository {
  UsageRepository({
    required CursorApiClient apiClient,
    required AppDatabase database,
    required Future<AgentUsage> Function(String agentId) loadAgentUsage,
  }) : this._(apiClient, database, loadAgentUsage);

  UsageRepository._(this._apiClient, this._database, this._loadAgentUsage);

  final CursorApiClient _apiClient;
  final AppDatabase _database;
  final Future<AgentUsage> Function(String agentId) _loadAgentUsage;

  static const _fallbackConcurrency = 4;

  Future<UsageReport> loadReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final spend = await _loadSpend();
      final events = await _loadUsageEvents(
        startDate: startDate,
        endDate: endDate,
      );
      return UsageReport(
        startDate: startDate,
        endDate: endDate,
        spend: spend,
        events: events,
      );
    } on UnauthorizedException catch (error, stackTrace) {
      developer.log(
        'Admin usage API rejected credentials.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return _fallbackReport(
        startDate: startDate,
        endDate: endDate,
        message: _adminUnavailableMessage,
      );
    } on ApiException catch (error, stackTrace) {
      developer.log(
        'Admin usage API failed.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      final message = error.statusCode == 403
          ? _adminUnavailableMessage
          : '${error.message} Showing best-effort cached agent usage.';
      return _fallbackReport(
        startDate: startDate,
        endDate: endDate,
        message: message,
      );
    } on AppException catch (error, stackTrace) {
      developer.log(
        'Usage API failed.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return _fallbackReport(
        startDate: startDate,
        endDate: endDate,
        message: '${error.message} Showing best-effort cached agent usage.',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Unable to load usage report.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return _fallbackReport(
        startDate: startDate,
        endDate: endDate,
        message:
            'Unable to load Admin API usage. Showing best-effort cached agent usage.',
      );
    }
  }

  Future<TeamSpendSummary> _loadSpend() async {
    final response = await _apiClient.postWithBasicAuth<Map<String, dynamic>>(
      '/teams/spend',
      data: const {'page': 1, 'pageSize': 100},
    );
    final payload = _asMap(response.data);
    final items = _items(payload);
    final total = items.fold<double>(0, (sum, item) {
      if (item is! Map) {
        return sum;
      }
      final map = _stringKeyedMap(item);
      return sum +
          (_doubleAt(map, const ['overallSpendCents', 'spendCents']) ?? 0);
    });
    return TeamSpendSummary(totalSpendCents: total, userCount: items.length);
  }

  Future<TeamUsageEventsSummary> _loadUsageEvents({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _apiClient.postWithBasicAuth<Map<String, dynamic>>(
      '/teams/filtered-usage-events',
      data: {
        'startDate': startDate.toUtc().millisecondsSinceEpoch,
        'endDate': endDate.toUtc().millisecondsSinceEpoch,
        'page': 1,
        'pageSize': 100,
      },
    );
    final payload = _asMap(response.data);
    final items = _items(payload);
    var chargedCents = 0.0;
    var totalTokens = 0;
    for (final item in items) {
      if (item is! Map) {
        continue;
      }
      final map = _stringKeyedMap(item);
      chargedCents += _doubleAt(map, const ['chargedCents', 'totalCents']) ?? 0;
      totalTokens += _tokenTotal(map);
    }
    return TeamUsageEventsSummary(
      eventCount: items.length,
      chargedCents: chargedCents,
      totalTokens: totalTokens,
    );
  }

  Future<UsageReport> _fallbackReport({
    required DateTime startDate,
    required DateTime endDate,
    required String message,
  }) async {
    final usage = await _loadFallbackUsage();
    return UsageReport(
      startDate: startDate,
      endDate: endDate,
      fallbackUsage: usage.$1,
      fallbackAgentCount: usage.$2,
      message: message,
      adminUnavailable: true,
    );
  }

  Future<(AgentUsage, int)> _loadFallbackUsage() async {
    final agents = await _database.agentsDao.getAll();
    final usages = <AgentUsage>[];
    for (
      var offset = 0;
      offset < agents.length;
      offset += _fallbackConcurrency
    ) {
      final end = offset + _fallbackConcurrency > agents.length
          ? agents.length
          : offset + _fallbackConcurrency;
      final chunk = agents.sublist(offset, end);
      final loaded = await Future.wait(
        chunk.map((agent) => _tryLoadAgentUsage(agent.id)),
      );
      usages.addAll(loaded.whereType<AgentUsage>());
    }

    final runs = usages.expand((usage) => usage.runs).toList(growable: false);
    final totalTokens = usages.fold<int>(
      0,
      (sum, usage) => sum + usage.totalTokens,
    );
    return (AgentUsage(totalTokens: totalTokens, runs: runs), usages.length);
  }

  Future<AgentUsage?> _tryLoadAgentUsage(String agentId) async {
    try {
      return await _loadAgentUsage(agentId);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to load fallback agent usage.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  List<Object?> _items(Map<String, Object?> payload) {
    final items =
        payload['items'] ??
        payload['data'] ??
        payload['usageEvents'] ??
        payload['usage_events'] ??
        payload['users'];
    return items is List ? items : const [];
  }

  int _tokenTotal(Map<String, Object?> json) {
    final direct = _intAt(json, const [
      'totalTokens',
      'total_tokens',
      'tokens',
    ]);
    if (direct != null) {
      return direct;
    }
    var total = 0;
    for (final key in const [
      'totalReadTokens',
      'totalWriteTokens',
      'inputTokens',
      'outputTokens',
      'cacheReadTokens',
      'cacheWriteTokens',
    ]) {
      total += _intAt(json, [key]) ?? 0;
    }
    return total;
  }

  Map<String, Object?> _asMap(Object? data) {
    if (data is Map) {
      return _stringKeyedMap(data);
    }
    throw const ApiException('Cursor usage response was invalid.');
  }

  Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> value) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  double? _doubleAt(Map<String, Object?> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  int? _intAt(Map<String, Object?> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.round();
      }
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}

const _adminUnavailableMessage =
    'Admin usage requires a Cursor Enterprise Admin API key. '
    'Showing best-effort token totals from cached agents.';
