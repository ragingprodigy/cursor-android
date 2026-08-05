import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

class AgentsPage extends HookWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cursor Cloud Agents',
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Agent list integration will land in the next task. '
                    'Your authenticated session is ready.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.go('/agents/new'),
                    icon: const Icon(Icons.bolt_outlined),
                    label: const Text('Create placeholder agent'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
