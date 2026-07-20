import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/time/time_zone_converter.dart';

void main() {
  const timeZones = IanaTimeZoneConverter();

  test('IANA conversion follows a daylight-saving transition', () {
    final before = timeZones.toTimeZone(
      DateTime.utc(2026, 3, 8, 6, 30),
      'America/New_York',
    );
    final after = timeZones.toTimeZone(
      DateTime.utc(2026, 3, 8, 7, 30),
      'America/New_York',
    );

    expect((before.hour, before.minute), (1, 30));
    expect((after.hour, after.minute), (3, 30));
    expect(before.timeZoneOffset, const Duration(hours: -5));
    expect(after.timeZoneOffset, const Duration(hours: -4));
  });

  test('local day and next midnight use the requested IANA zone', () {
    final instant = DateTime.utc(2026, 7, 20, 17);

    expect(timeZones.localDayKeyAt(instant, 'Asia/Shanghai'), '2026-07-21');
    expect(
      timeZones.localDayKeyAt(instant, 'America/Los_Angeles'),
      '2026-07-20',
    );
    expect(
      timeZones.untilNextLocalDay(
        DateTime.utc(2026, 3, 8, 5),
        'America/New_York',
      ),
      const Duration(hours: 23),
    );
  });
}
