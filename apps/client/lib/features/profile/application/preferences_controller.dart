import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../domain/app_preferences.dart';

final preferencesProvider = StreamProvider<AppPreferences>(
  (ref) => ref.watch(preferencesRepositoryProvider).watch(),
  dependencies: [preferencesRepositoryProvider],
);

enum NotificationAvailability { enabled, disabled, unavailable }

final notificationAvailabilityProvider = FutureProvider.autoDispose((
  ref,
) async {
  try {
    final enabled = await ref
        .watch(notificationServiceProvider)
        .notificationsEnabled();
    return enabled
        ? NotificationAvailability.enabled
        : NotificationAvailability.disabled;
  } catch (_) {
    return NotificationAvailability.unavailable;
  }
}, dependencies: [notificationServiceProvider]);

final preferencesMutationProvider =
    NotifierProvider<PreferencesMutationController, bool>(
      PreferencesMutationController.new,
      dependencies: [
        preferencesRepositoryProvider,
        fastingRepositoryProvider,
        notificationServiceProvider,
        notificationAvailabilityProvider,
      ],
    );

class PreferencesMutationController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<PreferencesMutationResult> setFastingReminder(bool enabled) async {
    if (state) {
      return PreferencesMutationResult.ignored;
    }
    state = true;
    try {
      if (enabled) {
        final notifications = ref.read(notificationServiceProvider);
        final bool permissionGranted;
        try {
          permissionGranted = await notifications
              .requestNotificationPermission();
        } catch (_) {
          ref.invalidate(notificationAvailabilityProvider);
          return PreferencesMutationResult.notificationUnavailable;
        }
        ref.invalidate(notificationAvailabilityProvider);
        if (!permissionGranted) {
          return PreferencesMutationResult.permissionDenied;
        }
      }
      final repository = ref.read(preferencesRepositoryProvider);
      final current = await repository.load();
      await repository.save(current.copyWith(fastingReminderEnabled: enabled));
      await _updateReminderBestEffort(enabled);
      ref.invalidate(notificationAvailabilityProvider);
      return PreferencesMutationResult.applied;
    } catch (_) {
      ref.invalidate(notificationAvailabilityProvider);
      return PreferencesMutationResult.failed;
    } finally {
      state = false;
    }
  }

  Future<void> _updateReminderBestEffort(bool enabled) async {
    try {
      final notifications = ref.read(notificationServiceProvider);
      if (!enabled) {
        await notifications.cancelFastingReminder();
        return;
      }
      final active = await ref.read(fastingRepositoryProvider).loadActive();
      await notifications.reconcile(active);
    } catch (_) {
      // The persisted preference remains valid if the OS permission is denied
      // or the notification plugin is temporarily unavailable.
    }
  }
}

enum PreferencesMutationResult {
  applied,
  ignored,
  permissionDenied,
  notificationUnavailable,
  failed,
}
