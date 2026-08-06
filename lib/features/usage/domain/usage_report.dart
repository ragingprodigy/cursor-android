import 'package:cursor/features/thread/domain/agent_usage.dart';
import 'package:equatable/equatable.dart';

class UsageReport extends Equatable {
  const UsageReport({
    required this.startDate,
    required this.endDate,
    this.spend,
    this.events,
    this.fallbackUsage,
    this.fallbackAgentCount = 0,
    this.message,
    this.adminUnavailable = false,
  });

  final DateTime startDate;
  final DateTime endDate;
  final TeamSpendSummary? spend;
  final TeamUsageEventsSummary? events;
  final AgentUsage? fallbackUsage;
  final int fallbackAgentCount;
  final String? message;
  final bool adminUnavailable;

  @override
  List<Object?> get props {
    return [
      startDate,
      endDate,
      spend,
      events,
      fallbackUsage,
      fallbackAgentCount,
      message,
      adminUnavailable,
    ];
  }
}

class TeamSpendSummary extends Equatable {
  const TeamSpendSummary({
    required this.totalSpendCents,
    required this.userCount,
  });

  final double totalSpendCents;
  final int userCount;

  @override
  List<Object?> get props => [totalSpendCents, userCount];
}

class TeamUsageEventsSummary extends Equatable {
  const TeamUsageEventsSummary({
    required this.eventCount,
    required this.chargedCents,
    required this.totalTokens,
  });

  final int eventCount;
  final double chargedCents;
  final int totalTokens;

  @override
  List<Object?> get props => [eventCount, chargedCents, totalTokens];
}
