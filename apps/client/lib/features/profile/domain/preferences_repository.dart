import 'app_preferences.dart';

abstract interface class PreferencesRepository {
  Future<AppPreferences> load();

  Stream<AppPreferences> watch();

  Future<void> save(AppPreferences preferences);
}
