import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/bootstrap/app_bootstrap.dart';
import 'package:foods_client/core/db/app_database.dart';
import 'package:foods_client/core/db/database_connection.dart';
import 'package:foods_client/core/security/database_key_store.dart';
import 'package:foods_client/core/time/device_time_zone.dart';

void main() {
  test(
    'bootstrap opens local storage without choosing an account scope',
    () async {
      final database = AppDatabase(NativeDatabase.memory());

      final dependencies = await AppBootstrapService(
        _FixedDatabaseFactory(database),
        const FixedDeviceTimeZone('Asia/Shanghai'),
      ).initialize();
      addTearDown(dependencies.dispose);

      expect(dependencies.database, same(database));
      expect(dependencies.timeZoneId, 'Asia/Shanghai');
    },
  );

  testWidgets('database-key recovery requires explicit confirmation', (
    tester,
  ) async {
    final factory = _RecoverableDatabaseFactory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appBootstrapServiceProvider.overrideWithValue(
            AppBootstrapService(
              factory,
              const FixedDeviceTimeZone('Asia/Shanghai'),
            ),
          ),
        ],
        child: const AppBootstrapHost(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bootstrap-reset-local-data')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bootstrap-reset-local-data')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bootstrap-reset-cancel')), findsOneWidget);
    expect(find.textContaining('尚未同步'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bootstrap-reset-cancel')));
    await tester.pumpAndSettle();
    expect(factory.resetCount, 0);

    await tester.tap(find.byKey(const Key('bootstrap-reset-local-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bootstrap-reset-confirm')));
    await tester.pump();
    await tester.pump();

    expect(factory.resetCount, 1);
  });
}

final class _FixedDatabaseFactory implements AppDatabaseFactory {
  const _FixedDatabaseFactory(this.database);

  final AppDatabase database;

  @override
  Future<AppDatabase> open() async => database;

  @override
  Future<void> reset() async {}
}

final class _RecoverableDatabaseFactory implements AppDatabaseFactory {
  int resetCount = 0;

  @override
  Future<AppDatabase> open() {
    throw MissingDatabaseKeyException();
  }

  @override
  Future<void> reset() async {
    resetCount++;
  }
}
