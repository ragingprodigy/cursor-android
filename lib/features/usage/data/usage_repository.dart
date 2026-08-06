import 'dart:developer' as developer;
import 'dart:math' as math;

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
  static const _pageSize = 100;
  static const _maxPages = 20;

  Future<UsageReport> loadReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    TeamSpendSummary? spend;
    TeamUsageEventsSummary? events;
    final warnings = <String>[];

    try {
      final spendResult = await _loadSpend();
      spend = spendResult.summary;
      if (spendResult.truncated) {
        warnings.add(
          spendResult.truncationReason == 'rate limited'
              ? 'Spend was rate-limited; showing partial team member totals.'
              : 'Spend shows the first ${_pageSize * spendResult.pagesLoaded} '
                    'team members (more pages available).',
        );
      }
    } on UnauthorizedException catch (error, stackTrace) {
      developer.log(
        'Admin spend API rejected credentials.',
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
      if (error.statusCode == 403) {
        developer.log(
          'Admin spend API forbidden.',
          name: 'UsageRepository',
          error: error,
          stackTrace: stackTrace,
        );
        return _fallbackReport(
          startDate: startDate,
          endDate: endDate,
          message: _adminUnavailableMessage,
        );
      }
      developer.log(
        'Admin spend API failed.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      warnings.add('Spend unavailable: ${error.message}');
    } on AppException catch (error, stackTrace) {
      developer.log(
        'Admin spend API failed.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      warnings.add('Spend unavailable: ${error.message}');
    } catch (error, stackTrace) {
      developer.log(
        'Unable to load Admin spend.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      warnings.add('Spend unavailable.');
    }

    try {
      final eventsResult = await _loadUsageEvents(
        startDate: startDate,
        endDate: endDate,
      );
      events = eventsResult.summary;
      if (eventsResult.truncated) {
        warnings.add(
          eventsResult.truncationReason == 'rate limited'
              ? 'Usage events were rate-limited; showing partial event totals.'
              : 'Usage events show the first '
                    '${_pageSize * eventsResult.pagesLoaded} events '
                    '(more pages available).',
        );
      }
    } on UnauthorizedException catch (error, stackTrace) {
      developer.log(
        'Admin usage-events API rejected credentials.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      if (spend == null) {
        return _fallbackReport(
          startDate: startDate,
          endDate: endDate,
          message: _adminUnavailableMessage,
        );
      }
      warnings.add(
        'Usage events require Admin access. Showing spend only where available.',
      );
    } on ApiException catch (error, stackTrace) {
      developer.log(
        'Admin usage-events API failed.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      if (error.statusCode == 403 && spend == null) {
        return _fallbackReport(
          startDate: startDate,
          endDate: endDate,
          message: _adminUnavailableMessage,
        );
      }
      warnings.add('Usage events unavailable: ${error.message}');
    } on AppException catch (error, stackTrace) {
      developer.log(
        'Admin usage-events API failed.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      warnings.add('Usage events unavailable: ${error.message}');
    } catch (error, stackTrace) {
      developer.log(
        'Unable to load Admin usage events.',
        name: 'UsageRepository',
        error: error,
        stackTrace: stackTrace,
      );
      warnings.add('Usage events unavailable.');
    }

    if (spend == null && events == null) {
      return _fallbackReport(
        startDate: startDate,
        endDate: endDate,
        message: warnings.isEmpty
            ? 'Unable to load Admin API usage. Showing best-effort cached agent usage.'
            : '${warnings.join(' ')} Showing best-effort cached agent usage.',
      );
    }

    return UsageReport(
      startDate: startDate,
      endDate: endDate,
      spend: spend,
      events: events,
      message: warnings.isEmpty ? null : warnings.join(' '),
    );
  }

  Future<_PagedSpend> _loadSpend() async {
    final members = <Object?>[];
    var page = 1;
    var totalPages = 1;
    var truncated = false;
    String? truncationReason;

    while (page <= totalPages && page <= _maxPages) {
      try {
        final response = await _apiClient
            .postWithBasicAuth<Map<String, dynamic>>(
              '/teams/spend',
              data: {'page': page, 'pageSize': _pageSize},
            );
        final payload = _asMap(response.data);
        members.addAll(_spendItems(payload));
        totalPages = math.max(1, _intAt(payload, const ['totalPages']) ?? 1);
        if (totalPages > _maxPages && page == _maxPages) {
          truncated = true;
          truncationReason ??= 'page cap';
        }
        page += 1;
      } on RateLimitedException {
        truncated = true;
        truncationReason = 'rate limited';
        break;
      }
    }

    if (totalPages > _maxPages) {
      truncated = true;
      truncationReason ??= 'page cap';
    }

    final total = members.fold<double>(0, (sum, item) {
      if (item is! Map) {
        return sum;
      }
      final map = _stringKeyedMap(item);
      return sum +
          (_doubleAt(map, const [
                'overallSpendCents',
                'spendCents',
                'includedSpendCents',
              ]) ??
              0);
    });

    if (members.isEmpty && truncated && truncationReason == 'rate limited') {
      throw const RateLimitedException(
        'Rate limited while loading team spend.',
      );
    }

    return _PagedSpend(
      summary: TeamSpendSummary(
        totalSpendCents: total,
        userCount: members.length,
      ),
      pagesLoaded: math.max(0, page - 1),
      truncated: truncated,
      truncationReason: truncationReason,
    );
  }

  Future<_PagedEvents> _loadUsageEvents({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final items = <Object?>[];
    var page = 1;
    var totalPages = 1;
    var truncated = false;
    String? truncationReason;

    while (page <= totalPages && page <= _maxPages) {
      try {
        final response = await _apiClient
            .postWithBasicAuth<Map<String, dynamic>>(
              '/teams/filtered-usage-events',
              data: {
                'startDate': startDate.toUtc().millisecondsSinceEpoch,
                'endDate': endDate.toUtc().millisecondsSinceEpoch,
                'page': page,
                'pageSize': _pageSize,
              },
            );
        final payload = _asMap(response.data);
        items.addAll(_eventItems(payload));
        totalPages = math.max(1, _intAt(payload, const ['totalPages']) ?? 1);
        if (totalPages > _maxPages && page == _maxPages) {
          truncated = true;
          truncationReason ??= 'page cap';
        }
        page += 1;
      } on RateLimitedException {
        truncated = true;
        truncationReason = 'rate limited';
        break;
      }
    }

    if (totalPages > _maxPages) {
      truncated = true;
      truncationReason ??= 'page cap';
    }

    if (items.isEmpty && truncated && truncationReason == 'rate limited') {
      throw const RateLimitedException(
        'Rate limited while loading usage events.',
      );
    }

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
    return _PagedEvents(
      summary: TeamUsageEventsSummary(
        eventCount: items.length,
        chargedCents: chargedCents,
        totalTokens: totalTokens,
      ),
      pagesLoaded: math.max(0, page - 1),
      truncated: truncated,
      truncationReason: truncationReason,
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
      message: '$message $_fallbackNotRangeFilteredNote',
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

  List<Object?> _spendItems(Map<String, Object?> payload) {
    final items =
        payload['teamMemberSpend'] ??
        payload['items'] ??
        payload['data'] ??
        payload['users'] ??
        payload['spend'];
    return items is List ? items : const [];
  }

  List<Object?> _eventItems(Map<String, Object?> payload) {
    final items =
        payload['usageEvents'] ??
        payload['usage_events'] ??
        payload['items'] ??
        payload['data'];
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

    final nested = json['tokenUsage'];
    if (nested is Map) {
      final tokenUsage = _stringKeyedMap(nested);
      final nestedTotal = _intAt(tokenUsage, const [
        'totalTokens',
        'total_tokens',
        'tokens',
      ]);
      if (nestedTotal != null) {
        return nestedTotal;
      }
      var nestedSum = 0;
      for (final key in const [
        'inputTokens',
        'outputTokens',
        'cacheReadTokens',
        'cacheWriteTokens',
        'totalReadTokens',
        'totalWriteTokens',
      ]) {
        nestedSum += _intAt(tokenUsage, [key]) ?? 0;
      }
      if (nestedSum > 0) {
        return nestedSum;
      }
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

class _PagedSpend {
  const _PagedSpend({
    required this.summary,
    required this.pagesLoaded,
    required this.truncated,
    this.truncationReason,
  });

  final TeamSpendSummary summary;
  final int pagesLoaded;
  final bool truncated;
  final String? truncationReason;
}

class _PagedEvents {
  const _PagedEvents({
    required this.summary,
    required this.pagesLoaded,
    required this.truncated,
    this.truncationReason,
  });

  final TeamUsageEventsSummary summary;
  final int pagesLoaded;
  final bool truncated;
  final String? truncationReason;
}

const _adminUnavailableMessage =
    'Admin usage requires a Cursor Enterprise Admin API key. '
    'Showing best-effort token totals from cached agents.';

const _fallbackNotRangeFilteredNote =
    'Cached agent totals are not filtered to the selected date range.';
