import 'fasting_plan.dart';
import 'fasting_session.dart';

abstract interface class FastingRepository {
  Future<FastingSession?> loadActive();

  Future<List<FastingSession>> loadRecent({int limit = 30});

  Stream<FastingStatistics> watchStatistics({required String timeZoneId});

  Future<FastingSession> start({
    required FastingPlan plan,
    required DateTime nowUtc,
    required String timeZoneId,
  });

  Future<void> cancelActive({required DateTime nowUtc});

  Future<bool> completeDue({required DateTime nowUtc});
}
