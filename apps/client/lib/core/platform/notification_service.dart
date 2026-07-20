import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../../features/fasting/domain/fasting_session.dart';
import '../time/app_clock.dart';

const fastingEndNotificationId = 41001;

abstract interface class NotificationService {
  Future<bool> notificationsEnabled();

  Future<bool> requestNotificationPermission();

  Future<void> reconcile(
    FastingSession? activeSession, {
    bool requestPermission = false,
  });

  Future<void> cancelFastingReminder();
}

final class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> cancelFastingReminder() async {}

  @override
  Future<bool> notificationsEnabled() async => false;

  @override
  Future<bool> requestNotificationPermission() async => false;

  @override
  Future<void> reconcile(
    FastingSession? activeSession, {
    bool requestPermission = false,
  }) async {}
}

abstract interface class LocalNotificationsGateway {
  Future<bool> initialize();

  Future<bool> notificationsEnabled();

  Future<bool> requestNotificationPermission();

  Future<void> scheduleFastingEnd({
    required int id,
    required time_zone.TZDateTime scheduledDate,
  });

  Future<void> cancel(int id);
}

final class FastingNotificationService implements NotificationService {
  factory FastingNotificationService({
    required LocalNotificationsGateway gateway,
    required AppClock clock,
  }) => FastingNotificationService._(gateway, clock);

  FastingNotificationService._(this._gateway, this._clock);

  final LocalNotificationsGateway _gateway;
  final AppClock _clock;

  Future<void>? _initialization;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<bool> notificationsEnabled() {
    return _serialize(() async {
      await _ensureInitialized();
      return _gateway.notificationsEnabled();
    });
  }

  @override
  Future<bool> requestNotificationPermission() {
    return _serialize(() async {
      await _ensureInitialized();
      return _gateway.requestNotificationPermission();
    });
  }

  @override
  Future<void> reconcile(
    FastingSession? activeSession, {
    bool requestPermission = false,
  }) {
    return _serialize(() async {
      await _ensureInitialized();

      if (activeSession == null) {
        if (requestPermission) {
          await _gateway.requestNotificationPermission();
        }
        await _gateway.cancel(fastingEndNotificationId);
        return;
      }

      final nowUtc = _clock.now().toUtc();
      if (!activeSession.targetEndAtUtc.isAfter(nowUtc)) {
        await _gateway.cancel(fastingEndNotificationId);
        return;
      }

      final enabled = requestPermission
          ? await _gateway.requestNotificationPermission()
          : await _gateway.notificationsEnabled();
      if (!enabled) {
        await _gateway.cancel(fastingEndNotificationId);
        return;
      }

      final scheduledDate = _toScheduledDate(activeSession);
      await _gateway.cancel(fastingEndNotificationId);
      await _gateway.scheduleFastingEnd(
        id: fastingEndNotificationId,
        scheduledDate: scheduledDate,
      );
    });
  }

  @override
  Future<void> cancelFastingReminder() {
    return _serialize(() async {
      await _ensureInitialized();
      await _gateway.cancel(fastingEndNotificationId);
    });
  }

  Future<void> _ensureInitialized() async {
    final existing = _initialization;
    if (existing != null) {
      await existing;
      return;
    }

    final pending = Future<void>.sync(() async {
      final initialized = await _gateway.initialize();
      if (!initialized) {
        throw StateError('The notification plugin could not initialize.');
      }
    });
    _initialization = pending;
    try {
      await pending;
    } catch (_) {
      if (identical(_initialization, pending)) {
        _initialization = null;
      }
      rethrow;
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static bool _timeZonesInitialized = false;

  static time_zone.TZDateTime _toScheduledDate(FastingSession session) {
    if (!_timeZonesInitialized) {
      time_zone_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }

    var identifier = session.timeZoneId.trim();
    if (identifier == 'UTC' || identifier == 'GMT' || identifier == 'Etc/GMT') {
      identifier = 'Etc/UTC';
    }
    if (identifier.isEmpty) {
      throw ArgumentError.value(
        session.timeZoneId,
        'timeZoneId',
        'The IANA time-zone identifier cannot be empty.',
      );
    }

    try {
      return time_zone.TZDateTime.from(
        session.targetEndAtUtc.toUtc(),
        time_zone.getLocation(identifier),
      );
    } on time_zone.LocationNotFoundException {
      throw ArgumentError.value(
        session.timeZoneId,
        'timeZoneId',
        'Unknown IANA time-zone identifier.',
      );
    }
  }
}

final class FlutterLocalNotificationsGateway
    implements LocalNotificationsGateway {
  FlutterLocalNotificationsGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('ordin_notification'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
    macOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
    windows: WindowsInitializationSettings(
      appName: '好好吃饭',
      appUserModelId: 'Ordin.Foods.Client',
      guid: 'f6d2a799-0bd1-4ee2-9d28-8cb86e5c3230',
    ),
  );

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'fasting_reminders',
      '断食提醒',
      channelDescription: '在断食目标结束时提醒你',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
    windows: WindowsNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<bool> initialize() async =>
      await _plugin.initialize(settings: _initializationSettings) ?? false;

  @override
  Future<bool> notificationsEnabled() async {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled() ??
            false,
      TargetPlatform.iOS =>
        (await _plugin
                    .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin
                    >()
                    ?.checkPermissions())
                ?.isEnabled ??
            false,
      TargetPlatform.macOS =>
        (await _plugin
                    .resolvePlatformSpecificImplementation<
                      MacOSFlutterLocalNotificationsPlugin
                    >()
                    ?.checkPermissions())
                ?.isEnabled ??
            false,
      TargetPlatform.windows => true,
      TargetPlatform.fuchsia || TargetPlatform.linux => false,
    };
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false,
      TargetPlatform.iOS =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true) ??
            false,
      TargetPlatform.macOS =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true) ??
            false,
      TargetPlatform.windows => true,
      TargetPlatform.fuchsia || TargetPlatform.linux => false,
    };
  }

  @override
  Future<void> scheduleFastingEnd({
    required int id,
    required time_zone.TZDateTime scheduledDate,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: '断食完成',
      body: '本次断食已结束，可以开始进食了。',
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'fasting',
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
