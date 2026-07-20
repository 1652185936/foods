import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_clock.dart';
import 'device_time_zone.dart';
import 'time_zone_converter.dart';

String localDayKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

DateTime shiftLocalCalendarDays(DateTime localDay, int dayDelta) {
  return DateTime(localDay.year, localDay.month, localDay.day + dayDelta);
}

typedef LocalDayRolloverDelay =
    Duration Function(DateTime now, String timeZoneId);

final localDayRolloverDelayProvider = Provider<LocalDayRolloverDelay>((ref) {
  final timeZones = ref.watch(timeZoneConverterProvider);
  return (now, timeZoneId) =>
      timeZones.untilNextLocalDay(now, timeZoneId) +
      const Duration(milliseconds: 50);
});

final currentLocalDayProvider = NotifierProvider<LocalDayController, DateTime>(
  LocalDayController.new,
  dependencies: [
    currentTimeZoneIdProvider,
    appClockProvider,
    timeZoneConverterProvider,
    localDayRolloverDelayProvider,
  ],
);

final class LocalDayController extends Notifier<DateTime> {
  Timer? _rolloverTimer;

  @override
  DateTime build() {
    ref.watch(currentTimeZoneIdProvider);
    ref.onDispose(() => _rolloverTimer?.cancel());
    final day = _readCurrentDay();
    _scheduleRollover();
    return day;
  }

  void refresh() {
    final day = _readCurrentDay();
    if (day != state) {
      state = day;
    }
    _scheduleRollover();
  }

  DateTime _readCurrentDay() {
    final timeZoneId = ref.read(currentTimeZoneIdProvider);
    final now = ref
        .read(timeZoneConverterProvider)
        .toTimeZone(ref.read(appClockProvider).now(), timeZoneId);
    return DateTime(now.year, now.month, now.day);
  }

  void _scheduleRollover() {
    _rolloverTimer?.cancel();
    final now = ref.read(appClockProvider).now();
    final timeZoneId = ref.read(currentTimeZoneIdProvider);
    final requestedDelay = ref.read(localDayRolloverDelayProvider)(
      now,
      timeZoneId,
    );
    final delay = requestedDelay <= Duration.zero
        ? const Duration(milliseconds: 1)
        : requestedDelay;
    _rolloverTimer = Timer(delay, refresh);
  }
}
