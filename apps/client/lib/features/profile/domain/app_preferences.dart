import '../../fasting/domain/fasting_plan.dart';

class AppPreferences {
  const AppPreferences({
    this.dailyEnergyTargetKcal = 1780,
    this.selectedFastingPlan = FastingPlan.balanced,
    this.fastingReminderEnabled = false,
    this.serverVersion = 0,
  });

  final int dailyEnergyTargetKcal;
  final FastingPlan selectedFastingPlan;
  final bool fastingReminderEnabled;
  final int serverVersion;

  AppPreferences copyWith({
    int? dailyEnergyTargetKcal,
    FastingPlan? selectedFastingPlan,
    bool? fastingReminderEnabled,
    int? serverVersion,
  }) {
    return AppPreferences(
      dailyEnergyTargetKcal:
          dailyEnergyTargetKcal ?? this.dailyEnergyTargetKcal,
      selectedFastingPlan: selectedFastingPlan ?? this.selectedFastingPlan,
      fastingReminderEnabled:
          fastingReminderEnabled ?? this.fastingReminderEnabled,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'dailyEnergyTargetKcal': dailyEnergyTargetKcal,
    'selectedFastingPlan': selectedFastingPlan.name,
    'fastingReminderEnabled': fastingReminderEnabled,
  };
}
