import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/platform/notification_service.dart';
import 'package:foods_client/features/fasting/domain/fasting_session.dart';
import 'package:foods_client/features/profile/domain/app_preferences.dart';
import 'package:foods_client/features/profile/presentation/profile_page.dart';

import '../../support/test_dependencies.dart';

void main() {
  testWidgets(
    'revoked permission is shown as unavailable and recovers after grant',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notifications = _PermissionNotificationService();
      final preferences = FakePreferencesRepository(
        const AppPreferences(fastingReminderEnabled: true),
      );

      await tester.pumpWidget(
        testProviderScope(
          preferences: preferences,
          notifications: notifications,
          child: const MaterialApp(home: Scaffold(body: ProfilePage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('系统通知权限已关闭，请在系统设置中允许通知'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('fasting-reminder-switch')),
            )
            .value,
        isFalse,
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('未获得系统通知权限，请在系统设置中允许通知'), findsWidgets);
      expect(preferences.current.fastingReminderEnabled, isTrue);

      notifications.permissionGranted = true;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('断食结束时提醒我'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('fasting-reminder-switch')),
            )
            .value,
        isTrue,
      );
      expect(notifications.permissionRequests, 2);
    },
  );
}

final class _PermissionNotificationService implements NotificationService {
  bool permissionGranted = false;
  bool permissionEnabled = false;
  int permissionRequests = 0;

  @override
  Future<void> cancelFastingReminder() async {}

  @override
  Future<bool> notificationsEnabled() async => permissionEnabled;

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests++;
    permissionEnabled = permissionGranted;
    return permissionGranted;
  }

  @override
  Future<void> reconcile(
    FastingSession? activeSession, {
    bool requestPermission = false,
  }) async {}
}
