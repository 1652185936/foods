import 'fasting_plan.dart';

enum FastingSessionStatus { active, completed, cancelled }

class FastingSession {
  const FastingSession({
    required this.id,
    required this.plan,
    required this.status,
    required this.startedAtUtc,
    required this.targetEndAtUtc,
    required this.timeZoneId,
    required this.startedLocalDay,
    required this.targetEndLocalDay,
    this.endedLocalDay,
    this.endedAtUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.serverVersion = 0,
  });

  final String id;
  final FastingPlan plan;
  final FastingSessionStatus status;
  final DateTime startedAtUtc;
  final DateTime targetEndAtUtc;
  final String timeZoneId;
  final String startedLocalDay;
  final String targetEndLocalDay;
  final String? endedLocalDay;
  final DateTime? endedAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int serverVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'plan': plan.name,
    'status': status.name,
    'startedAtUtc': startedAtUtc.toUtc().toIso8601String(),
    'targetEndAtUtc': targetEndAtUtc.toUtc().toIso8601String(),
    'timeZoneId': timeZoneId,
    'startedLocalDay': startedLocalDay,
    'targetEndLocalDay': targetEndLocalDay,
    'endedLocalDay': endedLocalDay,
    'endedAtUtc': endedAtUtc?.toUtc().toIso8601String(),
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
  };
}

class FastingStatistics {
  const FastingStatistics({
    this.completedCount = 0,
    this.completedThisWeek = 0,
    this.currentStreak = 0,
    this.completionRatePercent = 0,
  });

  final int completedCount;
  final int completedThisWeek;
  final int currentStreak;
  final int completionRatePercent;
}
