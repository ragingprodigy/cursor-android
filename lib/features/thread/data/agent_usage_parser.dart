import 'dart:convert';

import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/thread/domain/agent_usage.dart';

/// Parses `GET /v1/agents/{id}/usage`.
///
/// Documented shape:
/// ```json
/// {
///   "totalUsage": { "inputTokens", "outputTokens", "cacheWriteTokens",
///                   "cacheReadTokens", "totalTokens" },
///   "runs": [{ "id": "...", "usage": { ...same fields... } }]
/// }
/// ```
/// Also accepts a legacy wrapper `{ "usage": { "totalTokens", "runs": [...] } }`
/// with flat per-run token fields.
AgentUsage parseAgentUsage(Object? data) {
  final payload = _asMap(data, 'Cursor usage response');
  final totals =
      _mapAt(payload, 'totalUsage') ??
      _mapAt(payload, 'usage') ??
      _mapAt(payload, 'agentUsage') ??
      payload;

  var runs = _runUsagesFromPayload(payload);
  if (runs.isEmpty) {
    runs = _runUsagesFromPayload(totals);
  }

  final explicitTotal = _tokenTotal(totals);
  final summedTotal = runs.fold<int>(0, (sum, run) => sum + run.totalTokens);
  return AgentUsage(
    totalTokens: explicitTotal > 0 ? explicitTotal : summedTotal,
    runs: runs,
  );
}

List<RunUsage> _runUsagesFromPayload(Map<String, Object?> payload) {
  final rawRuns =
      _listAt(payload, 'runs') ??
      _listAt(payload, 'items') ??
      _listAt(payload, 'runUsage') ??
      _listAt(payload, 'run_usage') ??
      _listAt(payload, 'usageByRun') ??
      const [];

  return [
    for (final item in rawRuns)
      if (item is Map)
        if (_runUsageFromMap(_stringKeyedMap(item)) case final usage?) usage,
  ];
}

RunUsage? _runUsageFromMap(Map<String, Object?> json) {
  final runId = _stringAt(json, const ['runId', 'run_id', 'id']);
  if (runId == null) {
    return null;
  }
  final tokenSource = _mapAt(json, 'usage') ?? json;
  final inputTokens = _intAt(tokenSource, const [
    'inputTokens',
    'input_tokens',
    'promptTokens',
    'prompt_tokens',
    'readTokens',
    'read_tokens',
    'totalReadTokens',
    'total_read_tokens',
  ]);
  final outputTokens = _intAt(tokenSource, const [
    'outputTokens',
    'output_tokens',
    'completionTokens',
    'completion_tokens',
    'writeTokens',
    'write_tokens',
    'totalWriteTokens',
    'total_write_tokens',
  ]);
  final totalTokens = _tokenTotal(tokenSource);
  return RunUsage(
    runId: runId,
    totalTokens: totalTokens > 0
        ? totalTokens
        : (inputTokens ?? 0) + (outputTokens ?? 0),
    inputTokens: inputTokens,
    outputTokens: outputTokens,
  );
}

int _tokenTotal(Map<String, Object?> json) {
  final direct = _intAt(json, const [
    'totalTokens',
    'total_tokens',
    'tokens',
    'tokenCount',
    'token_count',
  ]);
  if (direct != null) {
    return direct;
  }

  var total = 0;
  for (final keys in const [
    ['inputTokens', 'input_tokens'],
    ['outputTokens', 'output_tokens'],
    ['cacheWriteTokens', 'cache_write_tokens'],
    ['cacheReadTokens', 'cache_read_tokens'],
  ]) {
    total += _intAt(json, keys) ?? 0;
  }
  if (total > 0) {
    return total;
  }
  for (final keys in const [
    ['totalReadTokens', 'total_read_tokens'],
    ['totalWriteTokens', 'total_write_tokens'],
  ]) {
    total += _intAt(json, keys) ?? 0;
  }
  return total;
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
  return value.map((key, value) => MapEntry(key.toString(), _jsonValue(value)));
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

Map<String, Object?>? _mapAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map) {
    return _stringKeyedMap(value);
  }
  return null;
}

List<Object?>? _listAt(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is List ? value : null;
}

String? _stringAt(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
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
