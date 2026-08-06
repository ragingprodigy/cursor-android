import 'package:cursor/features/thread/data/thread_message_mapper.dart';
import 'package:cursor/features/thread/domain/agent_run.dart';
import 'package:cursor/features/thread/domain/thread_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps runs into ordered prompt and result messages', () {
    final messages = mapRunsToMessages([
      AgentRun(
        id: 'run-2',
        status: 'running',
        promptText: 'Keep going',
        resultText: null,
        createdAt: DateTime.utc(2026, 8, 5, 10, 5),
      ),
      AgentRun(
        id: 'run-1',
        status: 'completed',
        promptText: 'Build the app',
        resultText: 'Implemented the app',
        createdAt: DateTime.utc(2026, 8, 5, 10),
      ),
    ]);

    expect(messages, hasLength(3));
    expect(messages[0], isA<UserMessage>());
    expect((messages[0] as UserMessage).text, 'Build the app');
    expect(messages[1], isA<AssistantMessage>());
    expect((messages[1] as AssistantMessage).text, 'Implemented the app');
    expect(messages[2], isA<UserMessage>());
    expect((messages[2] as UserMessage).text, 'Keep going');
    expect(messages.whereType<AssistantMessage>(), hasLength(1));
  });

  test('maps stored tool steps between user prompt and assistant result', () {
    final messages = mapRunsToMessages([
      AgentRun(
        id: 'run-1',
        status: 'completed',
        promptText: 'Run tests',
        resultText: 'Tests are green',
        createdAt: DateTime.utc(2026, 8, 5, 10),
        payload: const {
          'toolSteps': [
            {
              'id': 'tool-1',
              'name': 'flutter test',
              'status': 'completed',
              'output': 'All tests passed',
            },
          ],
        },
      ),
    ]);

    expect(messages, hasLength(3));
    expect(messages[0], isA<UserMessage>());
    expect(messages[1], isA<ToolStepMessage>());
    expect((messages[1] as ToolStepMessage).label, 'flutter test');
    expect((messages[1] as ToolStepMessage).text, 'All tests passed');
    expect(messages[2], isA<AssistantMessage>());
  });

  test('maps stored thinking before assistant result', () {
    final messages = mapRunsToMessages(
      [
        AgentRun(
          id: 'run-1',
          status: 'completed',
          promptText: 'Run tests',
          resultText: 'Tests are green',
          createdAt: DateTime.utc(2026, 8, 5, 10),
        ),
      ],
      thinkingTextByRunId: const {'run-1': 'Checking test failures'},
    );

    expect(messages, hasLength(3));
    expect(messages[0], isA<UserMessage>());
    expect(messages[1], isA<ThinkingMessage>());
    expect((messages[1] as ThinkingMessage).text, 'Checking test failures');
    expect(messages[2], isA<AssistantMessage>());
  });

  test('fills missing prompt text from stored run prompts', () {
    final messages = mapRunsToMessages(
      [
        AgentRun(
          id: 'run-1',
          status: 'completed',
          resultText: 'Done',
          createdAt: DateTime.utc(2026, 8, 5, 10),
        ),
      ],
      promptTextByRunId: const {'run-1': 'Persisted prompt'},
    );

    expect(messages, hasLength(2));
    expect(messages.first, isA<UserMessage>());
    expect((messages.first as UserMessage).text, 'Persisted prompt');
  });

  test('uses pending initial prompt for the first run without prompt text', () {
    final messages = mapRunsToMessages([
      AgentRun(
        id: 'run-1',
        status: 'completed',
        resultText: 'Done',
        createdAt: DateTime.utc(2026, 8, 5, 10),
      ),
    ], pendingInitialPromptText: 'Pending launch prompt');

    expect(messages.first, isA<UserMessage>());
    expect((messages.first as UserMessage).text, 'Pending launch prompt');
  });

  test('uses explicit placeholder when result has no available prompt', () {
    final messages = mapRunsToMessages([
      AgentRun(
        id: 'run-1',
        status: 'completed',
        resultText: 'Done',
        createdAt: DateTime.utc(2026, 8, 5, 10),
      ),
    ]);

    expect(messages, hasLength(2));
    expect(messages.first, isA<UserMessage>());
    expect((messages.first as UserMessage).text, promptUnavailableText);
    expect(messages.last, isA<AssistantMessage>());
  });
}
