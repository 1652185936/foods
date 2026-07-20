import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/network/generated/models/fasting_session_response.dart';
import 'package:foods_client/core/network/generated/models/health_profile_input_model.dart';
import 'package:foods_client/core/network/generated/models/sync_change_response.dart';

void main() {
  test('date-only fields remain ISO date strings on the wire', () {
    final profile = HealthProfileInputModel.fromJson({
      'expectedVersion': 1,
      'birthDate': '1990-01-02',
    });
    final String? birthDate = profile.birthDate;

    expect(birthDate, '1990-01-02');
    expect(profile.toJson()['birthDate'], '1990-01-02');
  });

  test('nullable date-time fields remain nullable DateTime values', () {
    final fastingSession = FastingSessionResponse.fromJson({
      'changeCursor': 4,
      'createdAtUtc': '2026-07-20T08:00:00Z',
      'endedAtUtc': null,
      'endedLocalDay': null,
      'id': 'fasting-session-1',
      'plan': 'balanced',
      'startedAtUtc': '2026-07-20T08:00:00Z',
      'startedLocalDay': '2026-07-20',
      'status': 'active',
      'targetEndAtUtc': '2026-07-21T00:00:00Z',
      'targetEndLocalDay': '2026-07-21',
      'timeZoneId': 'Asia/Dubai',
      'updatedAtUtc': '2026-07-20T08:00:00Z',
      'version': 2,
    });
    final String startedLocalDay = fastingSession.startedLocalDay;
    final DateTime? endedAtUtc = fastingSession.endedAtUtc;

    expect(startedLocalDay, '2026-07-20');
    expect(endedAtUtc, isNull);

    final change = SyncChangeResponse.fromJson({
      'changeCursor': 5,
      'deletedAtUtc': '2026-07-20T09:30:00Z',
      'entityId': 'meal-1',
      'entityType': 'mealLog',
      'version': 3,
    });
    final DateTime? deletedAtUtc = change.deletedAtUtc;

    expect(deletedAtUtc, DateTime.utc(2026, 7, 20, 9, 30));
  });
}
