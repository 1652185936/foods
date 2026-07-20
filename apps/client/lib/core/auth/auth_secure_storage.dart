import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthSecureStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterAuthSecureStorage implements AuthSecureStorage {
  FlutterAuthSecureStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              migrateWithBackup: true,
              storageNamespace: storageNamespace,
            ),
            iOptions: IOSOptions(
              accountName: storageNamespace,
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            mOptions: MacOsOptions(
              accountName: storageNamespace,
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const storageNamespace = 'foods_auth';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
