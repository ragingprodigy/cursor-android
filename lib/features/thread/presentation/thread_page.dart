import 'dart:async';

import 'package:cursor/features/thread/domain/thread_message.dart';
import 'package:cursor/features/thread/presentation/thread_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ThreadPage extends HookWidget {
  const ThreadPage({super.key});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      context.read<ThreadBloc>().add(const ThreadStarted());
      return null;
    }, const []);

    return BlocBuilder<ThreadBloc, ThreadState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(state.agent?.name ?? 'Agent ${state.agentId}'),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _refresh(context),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      children: [
                        _ThreadHeader(state: state),
                        if (state.isOffline || state.isStale) ...[
                          const SizedBox(height: 12),
                          _StatusBanner(
                            icon: state.isOffline
                                ? Icons.cloud_off_outlined
                                : Icons.history_outlined,
                            message:
                                state.message ??
                                (state.isOffline
                                    ? 'Offline - showing cached thread.'
                                    : 'Showing cached thread.'),
                          ),
                        ],
                        if (state.status == ThreadStatus.failure &&
                            state.message != null) ...[
                          const SizedBox(height: 12),
                          _StatusBanner(
                            icon: Icons.error_outline,
                            message: state.message!,
                            isError: true,
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (state.isLoading)
                          const _LoadingPanel()
                        else if (state.messages.isEmpty)
                          _EmptyThreadPanel(
                            hasFailure: state.status == ThreadStatus.failure,
                          )
                        else
                          ...state.messages.map((message) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _MessageBubble(message: message),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const _ComposerStub(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refresh(BuildContext context) {
    final completer = Completer<void>();
    context.read<ThreadBloc>().add(ThreadRefreshed(completer: completer));
    return completer.future;
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.state});

  final ThreadState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agent = state.agent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.terminal_outlined,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent?.name ?? 'Agent ${state.agentId}',
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        agent?.id ?? state.agentId,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StatusPill(status: agent?.status ?? 'loading'),
              ],
            ),
            if (agent?.latestRunId != null) ...[
              const SizedBox(height: 12),
              Text(
                'Latest run ${agent!.latestRunId}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError
        ? theme.colorScheme.error
        : theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyThreadPanel extends StatelessWidget {
  const _EmptyThreadPanel({required this.hasFailure});

  final bool hasFailure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              hasFailure ? Icons.cloud_off_outlined : Icons.chat_bubble_outline,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              hasFailure ? 'Thread unavailable' : 'No messages yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasFailure
                  ? 'Pull to refresh when your connection is back.'
                  : 'Messages will appear here once the agent reports runs.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message is UserMessage) {
      return _TextBubble(
        label: 'You',
        text: message.text,
        icon: Icons.person_outline,
        alignment: Alignment.centerRight,
      );
    }
    if (message is AssistantMessage) {
      return _TextBubble(
        label: 'Cursor',
        text: message.text,
        icon: Icons.smart_toy_outlined,
        alignment: Alignment.centerLeft,
      );
    }
    return _ToolBubble(message: message as ToolStepMessage);
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.label,
    required this.text,
    required this.icon,
    required this.alignment,
  });

  final String label;
  final String text;
  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = alignment == Alignment.centerRight;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(label, style: theme.textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 10),
                Text(text, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolBubble extends StatelessWidget {
  const _ToolBubble({required this.message});

  final ToolStepMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.build_outlined, color: theme.colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    message.text ?? message.status,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerStub extends StatelessWidget {
  const _ComposerStub();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: TextField(
          enabled: false,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            hintText: 'Follow-up composer coming in Task 9',
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(theme, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _statusColor(ThemeData theme, String status) {
    switch (status.toLowerCase()) {
      case 'running':
      case 'active':
        return theme.colorScheme.primary;
      case 'completed':
      case 'succeeded':
      case 'success':
        return Colors.greenAccent.shade400;
      case 'failed':
      case 'error':
      case 'cancelled':
        return theme.colorScheme.error;
      case 'queued':
      case 'pending':
        return theme.colorScheme.secondary;
      default:
        return theme.colorScheme.outline;
    }
  }
}
