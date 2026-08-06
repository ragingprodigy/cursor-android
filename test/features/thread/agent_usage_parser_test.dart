import 'package:cursor/features/thread/data/agent_usage_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses documented Cloud Agents usage response', () {
    final usage = parseAgentUsage({
      'totalUsage': {
        'inputTokens': 12480,
        'outputTokens': 3110,
        'cacheWriteTokens': 18200,
        'cacheReadTokens': 42600,
        'totalTokens': 76390,
      },
      'runs': [
        {
          'id': 'run-2',
          'usageUuid': 'uuid-2',
          'usage': {
            'inputTokens': 6320,
            'outputTokens': 1450,
            'cacheWriteTokens': 7100,
            'cacheReadTokens': 21300,
            'totalTokens': 36170,
          },
        },
        {
          'id': 'run-1',
          'usage': {
            'inputTokens': 6160,
            'outputTokens': 1660,
            'cacheWriteTokens': 11100,
            'cacheReadTokens': 21300,
            'totalTokens': 40220,
          },
        },
      ],
    });

    expect(usage.totalTokens, 76390);
    expect(usage.runs, hasLength(2));
    expect(usage.runs.first.runId, 'run-2');
    expect(usage.runs.first.totalTokens, 36170);
    expect(usage.runs.first.inputTokens, 6320);
    expect(usage.runs.first.outputTokens, 1450);
    expect(usage.runs.last.runId, 'run-1');
    expect(usage.runs.last.totalTokens, 40220);
  });

  test('sums nested run usage when totalUsage.totalTokens is absent', () {
    final usage = parseAgentUsage({
      'totalUsage': {
        'inputTokens': 10,
        'outputTokens': 5,
        'cacheWriteTokens': 1,
        'cacheReadTokens': 2,
      },
      'runs': [
        {
          'id': 'run-a',
          'usage': {
            'inputTokens': 10,
            'outputTokens': 5,
            'cacheWriteTokens': 1,
            'cacheReadTokens': 2,
          },
        },
      ],
    });

    expect(usage.totalTokens, 18);
    expect(usage.runs.single.totalTokens, 18);
  });

  test('keeps compatibility with legacy flat usage wrapper shape', () {
    final usage = parseAgentUsage({
      'usage': {
        'totalTokens': 42,
        'runs': [
          {'runId': 'run-1', 'inputTokens': 10, 'outputTokens': 32},
        ],
      },
    });

    expect(usage.totalTokens, 42);
    expect(usage.runs.single.runId, 'run-1');
    expect(usage.runs.single.totalTokens, 42);
  });
}
