import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/db/database_provider.dart';
import 'package:foods_client/core/platform/notification_service.dart';
import 'package:foods_client/features/fasting/domain/fasting_session.dart';
import 'package:foods_client/features/profile/application/preferences_controller.dart';
import 'package:foods_client/features/profile/domain/app_preferences.dart';

import '../../support/test_dependencies.dart';

void main() {
  test(
    'post-persistence notification failure does not misreport the preference',
    () async {
      final preferences = FakePreferencesRepository(
        const AppPreferences(fastingReminderEnabled: false),
      );
      final notifications = _RecordingNotificationService(
        permissionGranted: true,
        throwOnReconcile: true,
      );
      final container = _container(preferences, notifications);
      addTearDown(container.dispose);

      final result = await container
          .read(preferencesMutationProvider.notifier)
          .setFastingReminder(true);

      expect(result, PreferencesMutationResult.applied);
      expect(preferences.current.fastingReminderEnabled, isTrue);
      expect(notifications.permissionRequests, 1);
      expect(notifications.reconcileCalls, 1);
    },
  );

  test('disabling persists even when reminder cancellation fails', () async {
    final preferences = FakePreferencesRepository();
    final notifications = _RecordingNotificationService(throwOnCancel: true);
    final container = _container(preferences, notifications);
    addTearDown(container.dispose);

    final result = await container
        .read(preferencesMutationProvider.notifier)
        .setFastingReminder(false);

    expect(result, PreferencesMutationResult.applied);
    expect(preferences.current.fastingReminderEnabled, isFalse);
    expect(notifications.cancelCalls, 1);
  });

  test('permission denial never persists an enabled preference', () async {
    final preferences = FakePreferencesRepository(
      const AppPreferences(fastingReminderEnabled: false),
    );
    final notifications = _RecordingNotificationService();
    final container = _container(preferences, notifications);
    addTearDown(container.dispose);

    final result = await container
        .read(preferencesMutationProvider.notifier)
        .setFastingReminder(true);

    expect(result, PreferencesMutationResult.permissionDenied);
    expect(preferences.current.fastingReminderEnabled, isFalse);
    expect(notifications.reconcileCalls, 0);
  });

  test(
    'notification service failure never persists an enabled preference',
    () async {
      final preferences = FakePreferencesRepository(
        const AppPreferences(fastingReminderEnabled: false),
      );
      final notifications = _RecordingNotificationService(
        throwOnPermissionRequest: true,
      );
      final container = _container(preferences, notifications);
      addTearDown(container.dispose);

      final result = await container
          .read(preferencesMutationProvider.notifier)
          .setFastingReminder(true);

      expect(result, PreferencesMutationResult.notificationUnavailable);
      expect(preferences.current.fastingReminderEnabled, isFalse);
      expect(notifications.reconcileCalls, 0);
    },
  );

  test(
    'revoked permission is exposed and can recover after granting',
    () async {
      final preferences = FakePreferencesRepository();
      final notifications = _RecordingNotificationService();
      final container = _container(preferences, notifications);
      addTearDown(container.dispose);

      expect(
        await container.read(notificationAvailabilityProvider.future),
        NotificationAvailability.disabled,
      );

      expect(
        await container
            .read(preferencesMutationProvider.notifier)
            .setFastingReminder(true),
        PreferencesMutationResult.permissionDenied,
      );

      notifications.permissionGranted = true;
      expect(
        await container
            .read(preferencesMutationProvider.notifier)
            .setFastingReminder(true),
        PreferencesMutationResult.applied,
      );
      expect(
        await container.read(notificationAvailabilityProvider.future),
        NotificationAvailability.enabled,
      );
    },
  );
}

ProviderContainer _container(
  FakePreferencesRepository preferences,
  NotificationService notifications,
) {
  return ProviderContainer.test(
    overrides: [
      preferencesRepositoryProvider.overrideWithValue(preferences),
      fastingRepositoryProvider.overrideWithValue(FakeFastingRepository()),
      notificationServiceProvider.overrideWithValue(notifications),
    ],
  );
}

final class _RecordingNotificationService implements NotificationService {
  _RecordingNotificationService({
    this.permissionGranted = false,
    this.throwOnReconcile = false,
    this.throwOnCancel = false,
    this.throwOnPermissionRequest = false,
  });

  bool permissionGranted;
  final bool throwOnReconcile;
  final bool throwOnCancel;
  final bool throwOnPermissionRequest;
  bool permissionEnabled = false;
  int cancelCalls = 0;
  int permissionRequests = 0;
  int reconcileCalls = 0;

  @override
  Future<void> cancelFastingReminder() async {
    cancelCalls++;
    if (throwOnCancel) {
      throw StateError('notification plugin unavailable');
    }
  }

  @override
  Future<bool> notificationsEnabled() async => permissionEnabled;

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests++;
    if (throwOnPermissionRequest) {
      throw StateError('notification plugin unavailable');
    }
    permissionEnabled = permissionGranted;
    return permissionGranted;
  }

  @override
  Future<void> reconcile(
    FastingSession? activeSession, {
    bool requestPermission = false,
  }) async {
    reconcileCalls++;
    if (throwOnReconcile) {
      throw StateError('notification plugin unavailable');
    }
  }
}
