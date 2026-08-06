import 'package:cursor/features/thread/domain/agent_run.dart';
import 'package:cursor/features/thread/domain/thread_message.dart';

const promptUnavailableText = '(Prompt unavailable on this device)';

/// Orders runs the same way the conversation is rendered: ascending by
/// [AgentRun.createdAt], falling back to original list order on ties.
List<AgentRun> sortRunsByCreatedAt(Iterable<AgentRun> runs) {
  final indexedRuns = runs.indexed.toList(growable: false)
    ..sort((left, right) {
      final comparison = left.$2.createdAt.compareTo(right.$2.createdAt);
      return comparison == 0 ? left.$1.compareTo(right.$1) : comparison;
    });
  return indexedRuns.map((indexed) => indexed.$2).toList(growable: false);
}

/// The most recent run, matching the ordering used by [mapRunsToMessages].
AgentRun? latestAgentRun(Iterable<AgentRun> runs) {
  final sorted = sortRunsByCreatedAt(runs);
  return sorted.isEmpty ? null : sorted.last;
}

List<ThreadMessage> mapRunsToMessages(
  Iterable<AgentRun> runs, {
  Map<String, String> promptTextByRunId = const {},
  Map<String, String> thinkingTextByRunId = const {},
  String? pendingInitialPromptText,
}) {
  final sortedRuns = sortRunsByCreatedAt(runs);
  final messages = <ThreadMessage>[];

  for (final indexedRun in sortedRuns.indexed) {
    final run = indexedRun.$2;
    final promptText =
        _blankToNull(run.promptText) ??
        _blankToNull(promptTextByRunId[run.id]) ??
        (indexedRun.$1 == 0 ? _blankToNull(pendingInitialPromptText) : null);
    final resultText = _blankToNull(run.resultText);
    if (promptText != null || resultText != null) {
      messages.add(
        UserMessage(
          id: '${run.id}:user',
          runId: run.id,
          text: promptText ?? promptUnavailableText,
          createdAt: run.createdAt,
        ),
      );
    }

    messages.addAll(_toolMessagesFromRun(run));

    final thinkingText = _blankToNull(thinkingTextByRunId[run.id]);
    if (thinkingText != null) {
      messages.add(
        ThinkingMessage(
          id: '${run.id}:thinking',
          runId: run.id,
          text: thinkingText,
          createdAt: run.createdAt,
        ),
      );
    }

    if (resultText != null) {
      messages.add(
        AssistantMessage(
          id: '${run.id}:assistant',
          runId: run.id,
          text: resultText,
          status: run.status,
          createdAt: run.updatedAt ?? run.createdAt,
        ),
      );
    }
  }

  return List.unmodifiable(messages);
}

List<ToolStepMessage> _toolMessagesFromRun(AgentRun run) {
  final rawSteps = _toolStepPayloads(run.payload);
  return [
    for (final indexedStep in rawSteps.indexed)
      ToolStepMessage(
        id: _toolMessageId(run.id, indexedStep.$1, indexedStep.$2),
        runId: run.id,
        label: _toolLabel(indexedStep.$2),
        status:
            _firstString(indexedStep.$2, const ['status', 'state']) ??
            'unknown',
        text: _toolText(indexedStep.$2),
        createdAt:
            _dateAt(indexedStep.$2, 'createdAt', 'created_at') ?? run.createdAt,
      ),
  ];
}

List<Map<String, Object?>> _toolStepPayloads(Map<String, Object?> payload) {
  final steps = <Map<String, Object?>>[];

  for (final key in const [
    'toolSteps',
    'tool_steps',
    'tools',
    'toolCalls',
    'tool_calls',
  ]) {
    steps.addAll(_mapsFromList(payload[key]));
  }

  for (final step in _mapsFromList(payload['steps'])) {
    if (_looksLikeToolStep(step)) {
      steps.add(step);
    }
  }

  return steps;
}

Iterable<Map<String, Object?>> _mapsFromList(Object? value) sync* {
  if (value is! List) {
    return;
  }

  for (final item in value) {
    if (item is Map) {
      yield item.map((key, value) => MapEntry(key.toString(), value));
    }
  }
}

bool _looksLikeToolStep(Map<String, Object?> step) {
  final type = _firstString(step, const ['type', 'kind', 'role']);
  if (type != null && type.toLowerCase().contains('tool')) {
    return true;
  }
  return _firstString(step, const ['toolName', 'tool_name', 'command']) != null;
}

String _toolMessageId(String runId, int index, Map<String, Object?> step) {
  final id = _firstString(step, const ['id', 'stepId', 'step_id']);
  if (id == null) {
    return '$runId:tool:$index';
  }
  return '$runId:tool:$id';
}

String _toolLabel(Map<String, Object?> step) {
  final direct = _firstString(step, const [
    'label',
    'title',
    'name',
    'toolName',
    'tool_name',
    'command',
  ]);
  if (direct != null) {
    return direct;
  }

  final tool = step['tool'];
  if (tool is String && tool.trim().isNotEmpty) {
    return tool.trim();
  }
  if (tool is Map) {
    return _firstString(
          tool.map((key, value) => MapEntry(key.toString(), value)),
          const ['name', 'label'],
        ) ??
        'Tool step';
  }
  return 'Tool step';
}

String? _toolText(Map<String, Object?> step) {
  return _firstString(step, const [
        'output',
        'text',
        'summary',
        'description',
      ]) ??
      _nestedText(step['result']) ??
      _nestedText(step['response']);
}

String? _nestedText(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  if (value is Map) {
    return _firstString(
      value.map((key, value) => MapEntry(key.toString(), value)),
      const ['text', 'summary', 'output'],
    );
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

DateTime? _dateAt(
  Map<String, Object?> json,
  String camelCase,
  String snakeCase,
) {
  final value = _firstString(json, [camelCase, snakeCase]);
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
