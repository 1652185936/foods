import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

abstract interface class TimeZoneConverter {
  DateTime toTimeZone(DateTime instant, String timeZoneId);

  String localDayKeyAt(DateTime instant, String timeZoneId);

  Duration untilNextLocalDay(DateTime instant, String timeZoneId);
}

final timeZoneConverterProvider = Provider<TimeZoneConverter>(
  (ref) => const IanaTimeZoneConverter(),
);

final class IanaTimeZoneConverter implements TimeZoneConverter {
  const IanaTimeZoneConverter();

  static bool _initialized = false;

  @override
  DateTime toTimeZone(DateTime instant, String timeZoneId) {
    final location = _location(timeZoneId);
    return time_zone.TZDateTime.from(instant.toUtc(), location);
  }

  @override
  String localDayKeyAt(DateTime instant, String timeZoneId) {
    final local = toTimeZone(instant, timeZoneId);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Duration untilNextLocalDay(DateTime instant, String timeZoneId) {
    final location = _location(timeZoneId);
    final local = time_zone.TZDateTime.from(instant.toUtc(), location);
    final nextDay = time_zone.TZDateTime(
      location,
      local.year,
      local.month,
      local.day + 1,
    );
    return nextDay.toUtc().difference(instant.toUtc());
  }

  static time_zone.Location _location(String timeZoneId) {
    if (!_initialized) {
      time_zone_data.initializeTimeZones();
      _initialized = true;
    }
    var identifier = timeZoneId.trim();
    if (identifier.isEmpty) {
      throw ArgumentError.value(
        timeZoneId,
        'timeZoneId',
        'The IANA time-zone identifier cannot be empty.',
      );
    }
    if (identifier == 'UTC' || identifier == 'GMT' || identifier == 'Etc/GMT') {
      identifier = 'Etc/UTC';
    }
    try {
      return time_zone.getLocation(identifier);
    } on time_zone.LocationNotFoundException {
      throw ArgumentError.value(
        timeZoneId,
        'timeZoneId',
        'Unknown IANA time-zone identifier.',
      );
    }
  }
}
