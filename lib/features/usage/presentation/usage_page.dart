import 'package:cursor/features/thread/domain/agent_usage.dart';
import 'package:cursor/features/usage/domain/usage_report.dart';
import 'package:cursor/features/usage/presentation/usage_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class UsagePage extends HookWidget {
  const UsagePage({super.key});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      context.read<UsageBloc>().add(const UsageStarted());
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(title: const Text('Usage')),
      body: SafeArea(
        child: BlocBuilder<UsageBloc, UsageState>(
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<UsageBloc>().add(
                  UsagePresetSelected(state.preset),
                );
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  _RangeControls(state: state),
                  if (state.message != null) ...[
                    const SizedBox(height: 16),
                    _MessageCard(message: state.message!),
                  ],
                  const SizedBox(height: 16),
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.report == null)
                    const _MessageCard(
                      message: 'Usage report has not loaded yet.',
                    )
                  else
                    _ReportView(report: state.report!),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RangeControls extends StatelessWidget {
  const _RangeControls({required this.state});

  final UsageState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Range', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            SegmentedButton<UsagePreset>(
              segments: const [
                ButtonSegment(value: UsagePreset.last7Days, label: Text('7d')),
                ButtonSegment(
                  value: UsagePreset.last30Days,
                  label: Text('30d'),
                ),
                ButtonSegment(value: UsagePreset.custom, label: Text('Custom')),
              ],
              selected: {state.preset},
              onSelectionChanged: (selected) async {
                final preset = selected.single;
                if (preset == UsagePreset.custom) {
                  await _selectCustomRange(context, state);
                  return;
                }
                context.read<UsageBloc>().add(UsagePresetSelected(preset));
              },
            ),
            const SizedBox(height: 12),
            Text(
              '${_formatDate(state.startDate)} - ${_formatDate(state.endDate)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Custom Admin API ranges are clamped to 30 days.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCustomRange(
    BuildContext context,
    UsageState state,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.now().toUtc(),
      initialDateRange: DateTimeRange(
        start: state.startDate.toLocal(),
        end: state.endDate.toLocal(),
      ),
    );
    if (picked == null || !context.mounted) {
      return;
    }
    context.read<UsageBloc>().add(
      UsageCustomRangeSelected(startDate: picked.start, endDate: picked.end),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    final spend = report.spend;
    final events = report.events;
    final fallback = report.fallbackUsage;
    return Column(
      children: [
        if (spend != null)
          _MetricCard(
            title: 'Team spend',
            value: _formatCurrency(spend.totalSpendCents),
            subtitle: '${spend.userCount} users in current billing cycle',
          ),
        if (events != null) ...[
          const SizedBox(height: 16),
          _MetricCard(
            title: 'Usage events',
            value: _formatInt(events.totalTokens),
            subtitle:
                '${events.eventCount} events - ${_formatCurrency(events.chargedCents)} charged',
          ),
        ],
        if (fallback != null) ...[
          const SizedBox(height: 16),
          _FallbackUsageCard(
            usage: fallback,
            agentCount: report.fallbackAgentCount,
          ),
        ],
      ],
    );
  }
}

class _FallbackUsageCard extends StatelessWidget {
  const _FallbackUsageCard({required this.usage, required this.agentCount});

  final AgentUsage usage;
  final int agentCount;

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      title: 'Cached agent token usage',
      value: _formatInt(usage.totalTokens),
      subtitle: '$agentCount agents with usage available',
      child: usage.runs.isEmpty
          ? const Text('No per-run cached usage details available.')
          : Column(
              children: [
                for (final run in usage.runs.take(20))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Run ${run.runId}'),
                    subtitle: Text('${_formatInt(run.totalTokens)} tokens'),
                  ),
              ],
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.child,
  });

  final String title;
  final String value;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            if (child != null) ...[const SizedBox(height: 12), child!],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

String _formatCurrency(double cents) {
  return '\$${(cents / 100).toStringAsFixed(2)}';
}

String _formatInt(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
