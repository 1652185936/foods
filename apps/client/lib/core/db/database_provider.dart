import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/fasting/data/drift_fasting_repository.dart';
import '../../features/fasting/domain/fasting_repository.dart';
import '../../features/meals/data/drift_meal_repository.dart';
import '../../features/meals/domain/meal_repository.dart';
import '../../features/profile/data/drift_preferences_repository.dart';
import '../../features/profile/domain/preferences_repository.dart';
import '../id/id_generator.dart';
import '../platform/notification_service.dart';
import '../time/app_clock.dart';
import '../time/time_zone_converter.dart';
import 'account_scope.dart';
import 'app_database.dart';

export '../time/app_clock.dart' show appClockProvider;
export '../time/device_time_zone.dart' show currentTimeZoneIdProvider;

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('AppDatabase must be provided by the bootstrap scope.');
}, dependencies: const []);

final accountScopeProvider = Provider<AccountScope>(
  (ref) => const AccountScope.localOnly(),
  dependencies: const [],
);

final idGeneratorProvider = Provider<IdGenerator>((ref) => UuidV7IdGenerator());

final localNotificationsGatewayProvider = Provider<LocalNotificationsGateway>(
  (ref) => FlutterLocalNotificationsGateway(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => FastingNotificationService(
    gateway: ref.watch(localNotificationsGatewayProvider),
    clock: ref.watch(appClockProvider),
  ),
  dependencies: [localNotificationsGatewayProvider, appClockProvider],
);

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => DriftMealRepository(
    database: ref.watch(appDatabaseProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
    timeZones: ref.watch(timeZoneConverterProvider),
    scope: ref.watch(accountScopeProvider),
  ),
  dependencies: [
    appDatabaseProvider,
    idGeneratorProvider,
    appClockProvider,
    timeZoneConverterProvider,
    accountScopeProvider,
  ],
);

final fastingRepositoryProvider = Provider<FastingRepository>(
  (ref) => DriftFastingRepository(
    database: ref.watch(appDatabaseProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
    timeZones: ref.watch(timeZoneConverterProvider),
    scope: ref.watch(accountScopeProvider),
  ),
  dependencies: [
    appDatabaseProvider,
    idGeneratorProvider,
    appClockProvider,
    timeZoneConverterProvider,
    accountScopeProvider,
  ],
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => DriftPreferencesRepository(
    database: ref.watch(appDatabaseProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
    scope: ref.watch(accountScopeProvider),
  ),
  dependencies: [
    appDatabaseProvider,
    idGeneratorProvider,
    appClockProvider,
    accountScopeProvider,
  ],
);
