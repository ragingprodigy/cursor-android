import 'dart:async';

import 'package:cursor/features/thread/domain/thread_message.dart';
import 'package:cursor/features/thread/presentation/thread_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class ThreadPage extends HookWidget {
  const ThreadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();
    final hasScrolledToLatest = useRef(false);

    useEffect(() {
      context.read<ThreadBloc>().add(const ThreadStarted());
      hasScrolledToLatest.value = false;
      return null;
    }, const []);

    return BlocConsumer<ThreadBloc, ThreadState>(
      listenWhen: (previous, next) {
        final previousMessages = previous.displayMessages;
        final nextMessages = next.displayMessages;
        if (nextMessages.isEmpty || next.isLoading) {
          return false;
        }

        final becameReady =
            (previous.isLoading || previousMessages.isEmpty) &&
            nextMessages.isNotEmpty;
        final grew = nextMessages.length > previousMessages.length;
        final liveGrew =
            (previous.liveAssistantText?.length ?? 0) <
            (next.liveAssistantText?.length ?? 0);
        final liveToolsGrew =
            previous.liveToolSteps.length < next.liveToolSteps.length;

        // First open: always scroll. Later updates: keep pinned to latest
        // while streaming / appending (chat-style follow).
        return becameReady ||
            !hasScrolledToLatest.value ||
            grew ||
            liveGrew ||
            liveToolsGrew;
      },
      listener: (context, state) {
        _scrollToLatestMessage(
          scrollController,
          onScrolled: () => hasScrolledToLatest.value = true,
        );
      },
      builder: (context, state) {
        final messages = state.displayMessages;
        return Scaffold(
          appBar: AppBar(
            title: Text(state.agent?.name ?? 'Agent ${state.agentId}'),
            actions: [
              if (state.canCancel || state.isCancelling)
                _CancelButton(state: state),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _refresh(context),
                    child: ListView(
                      controller: scrollController,
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
                        if (state.actionMessage != null) ...[
                          const SizedBox(height: 12),
                          _StatusBanner(
                            icon: Icons.info_outline,
                            message: state.actionMessage!,
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (state.isLoading)
                          const _LoadingPanel()
                        else if (messages.isEmpty)
                          _EmptyThreadPanel(
                            hasFailure: state.status == ThreadStatus.failure,
                          )
                        else ...[
                          for (final entry in messages.indexed)
                            _MessageEntry(
                              key: ValueKey(entry.$2.id),
                              index: entry.$1,
                              message: entry.$2,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                _Composer(state: state),
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

void _scrollToLatestMessage(
  ScrollController scrollController, {
  VoidCallback? onScrolled,
}) {
  void jump() {
    if (!scrollController.hasClients) {
      return;
    }
    final max = scrollController.position.maxScrollExtent;
    if (scrollController.offset < max) {
      scrollController.jumpTo(max);
    }
    onScrolled?.call();
  }

  // Markdown / entrance animations can grow extent after the first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    jump();
    WidgetsBinding.instance.addPostFrameCallback((_) => jump());
  });
}

class _MessageEntry extends StatelessWidget {
  const _MessageEntry({required this.index, required this.message, super.key});

  final int index;
  final ThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final durationMs = 180 + (index < 6 ? index * 25 : 150);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _MessageBubble(message: message),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.state});

  final ThreadState state;

  @override
  Widget build(BuildContext context) {
    if (state.isCancelling) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: 'Cancel run',
      icon: const Icon(Icons.stop_circle_outlined),
      onPressed: () {
        context.read<ThreadBloc>().add(const ThreadCancelRequested());
      },
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.state});

  final ThreadState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agent = state.agent;
    final url = agent?.url;

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
            if (url != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openAgentUrl(context, url),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open agent on web'),
                ),
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

Future<void> _openAgentUrl(BuildContext context, Uri url) async {
  final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open agent on web.')),
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
        useMarkdown: true,
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
    this.useMarkdown = false,
  });

  final String label;
  final String text;
  final IconData icon;
  final Alignment alignment;
  final bool useMarkdown;

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
                if (useMarkdown)
                  GptMarkdown(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    followLinkColor: true,
                    onLinkTap: (url, _) => _openMarkdownLink(context, url),
                  )
                else
                  Text(text, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openMarkdownLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }
  await _openAgentUrl(context, uri);
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

class _Composer extends HookWidget {
  const _Composer({required this.state});

  final ThreadState state;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: state.followUpDraft);

    useEffect(() {
      if (controller.text != state.followUpDraft) {
        controller.value = TextEditingValue(
          text: state.followUpDraft,
          selection: TextSelection.collapsed(
            offset: state.followUpDraft.length,
          ),
        );
      }
      return null;
    }, [state.followUpDraft]);

    final theme = Theme.of(context);
    final canSubmit = state.canSubmitFollowUp;
    final hint = state.isLatestRunActive
        ? 'Agent is working - send available once it finishes'
        : 'Send a follow-up message';

    void submit() {
      final text = controller.text.trim();
      if (text.isEmpty || !canSubmit) {
        return;
      }
      context.read<ThreadBloc>().add(ThreadFollowUpSubmitted(text));
    }

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onChanged: (text) {
                  context.read<ThreadBloc>().add(
                    ThreadFollowUpDraftChanged(text),
                  );
                },
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    state.isLatestRunActive
                        ? Icons.lock_clock_outlined
                        : Icons.chat_bubble_outline,
                  ),
                  hintText: hint,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: canSubmit ? submit : null,
              icon: state.isSendingFollowUp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
            ),
          ],
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
