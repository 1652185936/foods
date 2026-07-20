import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/platform/notification_service.dart';
import 'package:foods_client/features/fasting/domain/fasting_plan.dart';
import 'package:foods_client/features/fasting/domain/fasting_session.dart';
import 'package:timezone/timezone.dart' as time_zone;

import '../../support/test_dependencies.dart';

void main() {
  final nowUtc = DateTime.utc(2026, 7, 20, 8);

  test(
    'silent cold-start reconcile schedules only with existing permission',
    () async {
      final gateway = _FakeGateway(notificationsAreEnabled: true);
      final service = _service(gateway, nowUtc);
      final session = _session(
        targetEndAtUtc: nowUtc.add(const Duration(hours: 8)),
      );

      await service.reconcile(session);

      expect(gateway.initializeCalls, 1);
      expect(gateway.permissionRequests, 0);
      expect(gateway.permissionChecks, 1);
      expect(gateway.cancelledIds, <int>[fastingEndNotificationId]);
      expect(gateway.schedules.single.id, fastingEndNotificationId);
      expect(gateway.schedules.single.date.toUtc(), session.targetEndAtUtc);
    },
  );

  test(
    'explicit enable requests permission and schedules when granted',
    () async {
      final gateway = _FakeGateway(permissionGranted: true);
      final service = _service(gateway, nowUtc);

      await service.reconcile(
        _session(targetEndAtUtc: nowUtc.add(const Duration(hours: 8))),
        requestPermission: true,
      );

      expect(gateway.permissionRequests, 1);
      expect(gateway.permissionChecks, 0);
      expect(gateway.schedules, hasLength(1));
    },
  );

  test('denied permission cancels stale reminder without failing', () async {
    final gateway = _FakeGateway(permissionGranted: false);
    final service = _service(gateway, nowUtc);

    await service.reconcile(
      _session(targetEndAtUtc: nowUtc.add(const Duration(hours: 8))),
      requestPermission: true,
    );

    expect(gateway.permissionRequests, 1);
    expect(gateway.cancelledIds, <int>[fastingEndNotificationId]);
    expect(gateway.schedules, isEmpty);
  });

  test(
    'enabling with no active fast requests permission but does not schedule',
    () async {
      final gateway = _FakeGateway(permissionGranted: true);
      final service = _service(gateway, nowUtc);

      await service.reconcile(null, requestPermission: true);

      expect(gateway.permissionRequests, 1);
      expect(gateway.cancelledIds, <int>[fastingEndNotificationId]);
      expect(gateway.schedules, isEmpty);
    },
  );

  for (final offset in <Duration>[Duration.zero, const Duration(seconds: 1)]) {
    test('expired target is cancelled and never scheduled '
        '(${offset.inSeconds} second offset)', () async {
      final gateway = _FakeGateway(notificationsAreEnabled: true);
      final service = _service(gateway, nowUtc);

      await service.reconcile(
        _session(targetEndAtUtc: nowUtc.subtract(offset)),
      );

      expect(gateway.permissionRequests, 0);
      expect(gateway.permissionChecks, 0);
      expect(gateway.cancelledIds, <int>[fastingEndNotificationId]);
      expect(gateway.schedules, isEmpty);
    });
  }

  test(
    'reconcile replaces the prior reminder with the same fixed id',
    () async {
      final gateway = _FakeGateway(notificationsAreEnabled: true);
      final service = _service(gateway, nowUtc);

      await service.reconcile(
        _session(targetEndAtUtc: nowUtc.add(const Duration(hours: 8))),
      );
      await service.reconcile(
        _session(targetEndAtUtc: nowUtc.add(const Duration(hours: 10))),
      );

      expect(gateway.initializeCalls, 1);
      expect(gateway.cancelledIds, <int>[
        fastingEndNotificationId,
        fastingEndNotificationId,
      ]);
      expect(
        gateway.schedules.map((schedule) => schedule.id),
        everyElement(fastingEndNotificationId),
      );
      expect(
        gateway.schedules.last.date.toUtc(),
        nowUtc.add(const Duration(hours: 10)),
      );
    },
  );

  test(
    'cancel initializes once and removes only the fasting reminder',
    () async {
      final gateway = _FakeGateway();
      final service = _service(gateway, nowUtc);

      await service.cancelFastingReminder();
      await service.cancelFastingReminder();

      expect(gateway.initializeCalls, 1);
      expect(gateway.cancelledIds, <int>[
        fastingEndNotificationId,
        fastingEndNotificationId,
      ]);
    },
  );

  test('a plugin failure does not poison later reconciliation', () async {
    final gateway = _FakeGateway(
      notificationsAreEnabled: true,
      scheduleFailures: 1,
    );
    final service = _service(gateway, nowUtc);
    final session = _session(
      targetEndAtUtc: nowUtc.add(const Duration(hours: 8)),
    );

    await expectLater(service.reconcile(session), throwsStateError);
    await service.reconcile(session);

    expect(gateway.initializeCalls, 1);
    expect(gateway.schedules, hasLength(1));
  });

  test('initialize false is a failure and a later call retries', () async {
    final gateway = _FakeGateway(
      notificationsAreEnabled: true,
      initializationResults: <bool>[false, true],
    );
    final service = _service(gateway, nowUtc);
    final session = _session(
      targetEndAtUtc: nowUtc.add(const Duration(hours: 8)),
    );

    await expectLater(service.reconcile(session), throwsStateError);
    await service.reconcile(session);

    expect(gateway.initializeCalls, 2);
    expect(gateway.schedules, hasLength(1));
  });

  test('concurrent reconciliations are serialized', () async {
    final scheduleGate = Completer<void>();
    final gateway = _FakeGateway(
      notificationsAreEnabled: true,
      scheduleGate: scheduleGate,
    );
    final service = _service(gateway, nowUtc);

    final first = service.reconcile(
      _session(targetEndAtUtc: nowUtc.add(const Duration(hours: 8))),
    );
    await gateway.firstScheduleStarted.future;
    final second = service.reconcile(
      _session(targetEndAtUtc: nowUtc.add(const Duration(hours: 10))),
    );
    await Future<void>.delayed(Duration.zero);

    expect(gateway.permissionChecks, 1);
    expect(gateway.scheduleCalls, 1);

    scheduleGate.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(gateway.permissionChecks, 2);
    expect(gateway.scheduleCalls, 2);
    expect(
      gateway.schedules.last.date.toUtc(),
      nowUtc.add(const Duration(hours: 10)),
    );
  });

  test(
    'IANA conversion preserves the instant across a DST transition',
    () async {
      final targetUtc = DateTime.utc(2026, 3, 8, 7, 30);
      final gateway = _FakeGateway(notificationsAreEnabled: true);
      final service = _service(gateway, DateTime.utc(2026, 3, 8, 5));

      await service.reconcile(
        _session(targetEndAtUtc: targetUtc, timeZoneId: 'America/New_York'),
      );

      final scheduled = gateway.schedules.single.date;
      expect(scheduled.toUtc(), targetUtc);
      expect(scheduled.hour, 3);
      expect(scheduled.minute, 30);
      expect(scheduled.timeZoneOffset, const Duration(hours: -4));
    },
  );
}

FastingNotificationService _service(_FakeGateway gateway, DateTime nowUtc) {
  return FastingNotificationService(
    gateway: gateway,
    clock: MutableAppClock(nowUtc),
  );
}

FastingSession _session({
  required DateTime targetEndAtUtc,
  String timeZoneId = 'Asia/Shanghai',
}) {
  final startedAtUtc = targetEndAtUtc.subtract(
    FastingPlan.balanced.fastingDuration,
  );
  return FastingSession(
    id: 'fasting-session',
    plan: FastingPlan.balanced,
    status: FastingSessionStatus.active,
    startedAtUtc: startedAtUtc,
    targetEndAtUtc: targetEndAtUtc,
    timeZoneId: timeZoneId,
    startedLocalDay: '2026-07-20',
    targetEndLocalDay: '2026-07-21',
    createdAtUtc: startedAtUtc,
    updatedAtUtc: startedAtUtc,
  );
}

final class _ScheduleCall {
  const _ScheduleCall(this.id, this.date);

  final int id;
  final time_zone.TZDateTime date;
}

final class _FakeGateway implements LocalNotificationsGateway {
  _FakeGateway({
    this.notificationsAreEnabled = false,
    this.permissionGranted = false,
    this.scheduleFailures = 0,
    List<bool> initializationResults = const <bool>[true],
    this.scheduleGate,
  }) : initializationResults = List<bool>.of(initializationResults);

  bool notificationsAreEnabled;
  bool permissionGranted;
  int scheduleFailures;
  final List<bool> initializationResults;
  final Completer<void>? scheduleGate;
  int initializeCalls = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  int scheduleCalls = 0;
  final Completer<void> firstScheduleStarted = Completer<void>();
  final List<int> cancelledIds = <int>[];
  final List<_ScheduleCall> schedules = <_ScheduleCall>[];

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    if (initializationResults.isEmpty) {
      return true;
    }
    return initializationResults.removeAt(0);
  }

  @override
  Future<bool> notificationsEnabled() async {
    permissionChecks++;
    return notificationsAreEnabled;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleFastingEnd({
    required int id,
    required time_zone.TZDateTime scheduledDate,
  }) async {
    scheduleCalls++;
    if (!firstScheduleStarted.isCompleted) {
      firstScheduleStarted.complete();
    }
    await scheduleGate?.future;
    if (scheduleFailures > 0) {
      scheduleFailures--;
      throw StateError('notification plugin unavailable');
    }
    schedules.add(_ScheduleCall(id, scheduledDate));
  }
}
