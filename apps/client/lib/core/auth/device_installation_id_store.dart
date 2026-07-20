import 'dart:async';

import 'package:uuid/uuid.dart';

import 'auth_secure_storage.dart';

final class DeviceInstallationIdStore {
  DeviceInstallationIdStore(this._storage, {String Function()? generateId})
    : _generateId = generateId ?? const Uuid().v4;

  static const storageKey = 'foods.auth.device-installation-id.v1';

  final AuthSecureStorage _storage;
  final String Function() _generateId;
  Future<String>? _loadInFlight;

  Future<String> loadOrCreate() {
    final running = _loadInFlight;
    if (running != null) {
      return running;
    }

    final started = Future<String>.sync(_loadOrCreateOnce);
    _loadInFlight = started;
    return started.whenComplete(() {
      if (identical(_loadInFlight, started)) {
        _loadInFlight = null;
      }
    });
  }

  Future<String> _loadOrCreateOnce() async {
    final stored = await _storage.read(storageKey);
    if (stored != null && _isCanonicalUuid(stored)) {
      return stored;
    }

    final generated = _generateId().toLowerCase();
    if (!_isCanonicalUuid(generated)) {
      throw StateError(
        'The installation ID generator returned an invalid UUID.',
      );
    }
    if (stored != null) {
      await _storage.delete(storageKey);
    }
    await _storage.write(storageKey, generated);
    return generated;
  }

  static bool _isCanonicalUuid(String value) =>
      value == value.toLowerCase() &&
      Uuid.isValidUUID(fromString: value) &&
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(value);
}
