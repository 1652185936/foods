import 'package:drift/drift.dart';

import '../../../core/db/account_scope.dart';
import '../../../core/db/app_database.dart' as db;
import '../../../core/db/outbox_writer.dart';
import '../../../core/id/id_generator.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/local_day.dart';
import '../../../core/time/time_zone_converter.dart';
import '../domain/fasting_plan.dart';
import '../domain/fasting_repository.dart';
import '../domain/fasting_session.dart';

final class DriftFastingRepository implements FastingRepository {
  DriftFastingRepository({
    required db.AppDatabase database,
    required IdGenerator ids,
    required AppClock clock,
    required this.timeZones,
    required AccountScope scope,
  }) : _database = database,
       _ids = ids,
       _clock = clock,
       _scope = scope,
       _outbox = OutboxWriter(database, ids, clock, scope);

  final db.AppDatabase _database;
  final IdGenerator _ids;
  final AppClock _clock;
  final AccountScope _scope;
  final TimeZoneConverter timeZones;
  final OutboxWriter _outbox;

  @override
  Future<FastingSession?> loadActive() async {
    final query = _database.select(_database.fastingSessions)
      ..where(
        (row) =>
            row.ownerUserId.equals(_scope.ownerUserId) &
            row.activeSlot.equals(1),
      );
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapSession(row);
  }

  @override
  Future<List<FastingSession>> loadRecent({int limit = 30}) async {
    final query = _database.select(_database.fastingSessions)
      ..where((row) => row.ownerUserId.equals(_scope.ownerUserId))
      ..orderBy(<OrderingTerm Function(db.FastingSessions)>[
        (row) => OrderingTerm.desc(row.startedAtUtcMs),
      ])
      ..limit(limit);
    return (await query.get()).map(_mapSession).toList(growable: false);
  }

  @override
  Future<FastingSession> start({
    required FastingPlan plan,
    required DateTime nowUtc,
    required String timeZoneId,
  }) async {
    final startedAt = nowUtc.toUtc();
    final session = FastingSession(
      id: _ids.next(),
      plan: plan,
      status: FastingSessionStatus.active,
      startedAtUtc: startedAt,
      targetEndAtUtc: startedAt.add(plan.fastingDuration),
      timeZoneId: timeZoneId,
      startedLocalDay: timeZones.localDayKeyAt(startedAt, timeZoneId),
      targetEndLocalDay: timeZones.localDayKeyAt(
        startedAt.add(plan.fastingDuration),
        timeZoneId,
      ),
      createdAtUtc: startedAt,
      updatedAtUtc: startedAt,
      serverVersion: 0,
    );
    await _database.transaction(() async {
      final existing =
          await (_database.select(_database.fastingSessions)..where(
                (row) =>
                    row.ownerUserId.equals(_scope.ownerUserId) &
                    row.activeSlot.equals(1),
              ))
              .getSingleOrNull();
      if (existing != null) {
        throw const ActiveFastingSessionException();
      }
      await _database
          .into(_database.fastingSessions)
          .insert(
            db.FastingSessionsCompanion.insert(
              ownerUserId: _scope.ownerUserId,
              id: session.id,
              plan: session.plan.name,
              status: session.status.name,
              activeSlot: const Value(1),
              startedAtUtcMs: session.startedAtUtc.millisecondsSinceEpoch,
              targetEndAtUtcMs: session.targetEndAtUtc.millisecondsSinceEpoch,
              timeZoneId: session.timeZoneId,
              startedLocalDay: session.startedLocalDay,
              targetEndLocalDay: session.targetEndLocalDay,
              createdAtUtcMs: session.createdAtUtc.millisecondsSinceEpoch,
              updatedAtUtcMs: session.updatedAtUtc.millisecondsSinceEpoch,
              serverVersion: const Value(0),
            ),
          );
      await _outbox.add(
        entityType: 'fastingSession',
        entityId: session.id,
        action: 'upsert',
        payload: session.toJson(),
        expectedVersion: session.serverVersion,
      );
    });
    return session;
  }

  @override
  Future<void> cancelActive({required DateTime nowUtc}) async {
    final now = nowUtc.toUtc();
    await _database.transaction(() async {
      final row =
          await (_database.select(_database.fastingSessions)..where(
                (entry) =>
                    entry.ownerUserId.equals(_scope.ownerUserId) &
                    entry.activeSlot.equals(1),
              ))
              .getSingleOrNull();
      if (row == null) {
        return;
      }
      await (_database.update(_database.fastingSessions)..where(
            (entry) =>
                entry.ownerUserId.equals(_scope.ownerUserId) &
                entry.id.equals(row.id),
          ))
          .write(
            db.FastingSessionsCompanion(
              status: Value(FastingSessionStatus.cancelled.name),
              activeSlot: const Value(null),
              endedAtUtcMs: Value(now.millisecondsSinceEpoch),
              endedLocalDay: Value(
                timeZones.localDayKeyAt(now, row.timeZoneId),
              ),
              updatedAtUtcMs: Value(now.millisecondsSinceEpoch),
            ),
          );
      final updated = _mapSession(
        row.copyWith(
          status: FastingSessionStatus.cancelled.name,
          activeSlot: const Value(null),
          endedAtUtcMs: Value(now.millisecondsSinceEpoch),
          endedLocalDay: Value(timeZones.localDayKeyAt(now, row.timeZoneId)),
          updatedAtUtcMs: now.millisecondsSinceEpoch,
        ),
      );
      await _outbox.add(
        entityType: 'fastingSession',
        entityId: updated.id,
        action: 'upsert',
        payload: updated.toJson(),
        expectedVersion: row.serverVersion,
      );
    });
  }

  @override
  Future<bool> completeDue({required DateTime nowUtc}) async {
    final now = nowUtc.toUtc();
    return _database.transaction(() async {
      final row =
          await (_database.select(_database.fastingSessions)..where(
                (entry) =>
                    entry.ownerUserId.equals(_scope.ownerUserId) &
                    entry.activeSlot.equals(1),
              ))
              .getSingleOrNull();
      if (row == null || row.targetEndAtUtcMs > now.millisecondsSinceEpoch) {
        return false;
      }
      await (_database.update(_database.fastingSessions)..where(
            (entry) =>
                entry.ownerUserId.equals(_scope.ownerUserId) &
                entry.id.equals(row.id),
          ))
          .write(
            db.FastingSessionsCompanion(
              status: Value(FastingSessionStatus.completed.name),
              activeSlot: const Value(null),
              endedAtUtcMs: Value(row.targetEndAtUtcMs),
              endedLocalDay: Value(row.targetEndLocalDay),
              updatedAtUtcMs: Value(now.millisecondsSinceEpoch),
            ),
          );
      final updated = _mapSession(
        row.copyWith(
          status: FastingSessionStatus.completed.name,
          activeSlot: const Value(null),
          endedAtUtcMs: Value(row.targetEndAtUtcMs),
          endedLocalDay: Value(row.targetEndLocalDay),
          updatedAtUtcMs: now.millisecondsSinceEpoch,
        ),
      );
      await _outbox.add(
        entityType: 'fastingSession',
        entityId: updated.id,
        action: 'upsert',
        payload: updated.toJson(),
        expectedVersion: row.serverVersion,
      );
      return true;
    });
  }

  @override
  Stream<FastingStatistics> watchStatistics({required String timeZoneId}) {
    final query = _database.select(_database.fastingSessions)
      ..where(
        (row) =>
            row.ownerUserId.equals(_scope.ownerUserId) &
            row.activeSlot.isNull(),
      );
    return query.watch().map((rows) {
      final completed = rows
          .where((row) => row.status == FastingSessionStatus.completed.name)
          .toList();
      final eligibleCount = rows
          .where(
            (row) =>
                row.status == FastingSessionStatus.completed.name ||
                row.status == FastingSessionStatus.cancelled.name,
          )
          .length;
      final now = timeZones.toTimeZone(_clock.now(), timeZoneId);
      final startOfWeek = shiftLocalCalendarDays(
        DateTime(now.year, now.month, now.day),
        -(now.weekday - DateTime.monday),
      );
      final startOfWeekKey = localDayKey(startOfWeek);
      final completedThisWeek = completed.where((row) {
        final endedDay = row.endedLocalDay ?? row.targetEndLocalDay;
        return endedDay.compareTo(startOfWeekKey) >= 0;
      }).length;
      return FastingStatistics(
        completedCount: completed.length,
        completedThisWeek: completedThisWeek,
        currentStreak: _calculateStreak(completed, now),
        completionRatePercent: eligibleCount == 0
            ? 0
            : ((completed.length / eligibleCount) * 100).round(),
      );
    });
  }

  int _calculateStreak(List<db.FastingSession> completed, DateTime now) {
    final days = completed
        .map((row) => row.endedLocalDay ?? row.targetEndLocalDay)
        .toSet();
    if (days.isEmpty) {
      return 0;
    }
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(localDayKey(cursor))) {
      cursor = shiftLocalCalendarDays(cursor, -1);
    }
    var count = 0;
    while (days.contains(localDayKey(cursor))) {
      count++;
      cursor = shiftLocalCalendarDays(cursor, -1);
    }
    return count;
  }

  FastingSession _mapSession(db.FastingSession row) {
    return FastingSession(
      id: row.id,
      plan: FastingPlan.values.byName(row.plan),
      status: FastingSessionStatus.values.byName(row.status),
      startedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row.startedAtUtcMs,
        isUtc: true,
      ),
      targetEndAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row.targetEndAtUtcMs,
        isUtc: true,
      ),
      timeZoneId: row.timeZoneId,
      startedLocalDay: row.startedLocalDay,
      targetEndLocalDay: row.targetEndLocalDay,
      endedLocalDay: row.endedLocalDay,
      endedAtUtc: row.endedAtUtcMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.endedAtUtcMs!, isUtc: true),
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtUtcMs,
        isUtc: true,
      ),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtUtcMs,
        isUtc: true,
      ),
      serverVersion: row.serverVersion,
    );
  }
}

final class ActiveFastingSessionException implements Exception {
  const ActiveFastingSessionException();
}
