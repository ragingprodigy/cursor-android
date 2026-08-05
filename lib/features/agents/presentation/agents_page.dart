import 'dart:async';

import 'package:cursor/features/agents/domain/agent_summary.dart';
import 'package:cursor/features/agents/presentation/agents_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

class AgentsPage extends HookWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      context.read<AgentsBloc>().add(const AgentsStarted());
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cursor'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/agents/new'),
        icon: const Icon(Icons.add),
        label: const Text('New agent'),
      ),
      body: SafeArea(
        child: BlocBuilder<AgentsBloc, AgentsState>(
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () => _refresh(context),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                children: [
                  const _BrandHeader(),
                  if (state.isOffline || state.isStale) ...[
                    const SizedBox(height: 16),
                    _StaleBanner(isOffline: state.isOffline),
                  ],
                  if (state.status == AgentsStatus.failure &&
                      state.message != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: state.message!),
                  ],
                  const SizedBox(height: 20),
                  if (state.isLoading)
                    const _LoadingPanel()
                  else if (state.agents.isEmpty)
                    _EmptyAgentsPanel(
                      hasFailure: state.status == AgentsStatus.failure,
                    )
                  else
                    ...state.agents.map((agent) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AgentCard(agent: agent),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _refresh(BuildContext context) {
    final completer = Completer<void>();
    context.read<AgentsBloc>().add(AgentsRefreshed(completer: completer));
    return completer.future;
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
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
                  child: Icon(Icons.bolt, color: theme.colorScheme.onPrimary),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cursor', style: theme.textTheme.headlineLarge),
                    Text('Cloud Agents', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Monitor remote agents, resume work, and create new sessions '
              'from your phone.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.12),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.cloud_off_outlined : Icons.history_outlined,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isOffline
                  ? 'Offline - showing cached agents.'
                  : 'Showing cached agents while the list refreshes.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
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

class _EmptyAgentsPanel extends StatelessWidget {
  const _EmptyAgentsPanel({required this.hasFailure});

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
              hasFailure ? Icons.cloud_off_outlined : Icons.smart_toy_outlined,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              hasFailure ? 'Agents unavailable' : 'No agents yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasFailure
                  ? 'Pull to refresh when your connection is back.'
                  : 'Create your first Cursor Cloud Agent to get started.',
              textAlign: TextAlign.center,
            ),
            if (!hasFailure) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.go('/agents/new'),
                icon: const Icon(Icons.add),
                label: const Text('New agent'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});

  final AgentSummary agent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        onTap: () => context.go('/agents/${Uri.encodeComponent(agent.id)}'),
        title: Text(agent.name, style: theme.textTheme.titleLarge),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Updated ${_formatUpdatedAt(agent.updatedAt)}'),
        ),
        trailing: _StatusPill(status: agent.status),
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

String _formatUpdatedAt(DateTime value) {
  final now = DateTime.now().toUtc();
  final updatedAt = value.toUtc();
  final difference = now.difference(updatedAt);

  if (difference.inSeconds < 60) {
    return 'just now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }

  final month = updatedAt.month.toString().padLeft(2, '0');
  final day = updatedAt.day.toString().padLeft(2, '0');
  return '${updatedAt.year}-$month-$day';
}

class NewAgentPage extends HookWidget {
  const NewAgentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New agent')),
      body: const SafeArea(
        child: _PlaceholderPanel(
          icon: Icons.add_task_outlined,
          title: 'New agent',
          message: 'Agent creation UI placeholder.',
        ),
      ),
    );
  }
}

class AgentDetailPage extends HookWidget {
  const AgentDetailPage({required this.agentId, super.key});

  final String agentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Agent $agentId')),
      body: SafeArea(
        child: _PlaceholderPanel(
          icon: Icons.terminal_outlined,
          title: 'Agent detail',
          message: 'Thread and run controls placeholder for $agentId.',
        ),
      ),
    );
  }
}

class _PlaceholderPanel extends HookWidget {
  const _PlaceholderPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
