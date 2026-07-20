enum FastingPlan {
  gentle(label: '14:10', fastingHours: 14, eatingHours: 10),
  balanced(label: '16:8', fastingHours: 16, eatingHours: 8),
  advanced(label: '18:6', fastingHours: 18, eatingHours: 6);

  const FastingPlan({
    required this.label,
    required this.fastingHours,
    required this.eatingHours,
  });

  final String label;
  final int fastingHours;
  final int eatingHours;

  Duration get fastingDuration => Duration(hours: fastingHours);
  Duration get eatingDuration => Duration(hours: eatingHours);
}
