import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/auth_secure_storage.dart';
import 'package:foods_client/core/auth/device_installation_id_store.dart';

void main() {
  const generated = '550e8400-e29b-41d4-a716-446655440000';

  test('creates and reuses a random installation UUID', () async {
    final storage = _MemoryAuthSecureStorage();
    var generationCount = 0;
    final store = DeviceInstallationIdStore(
      storage,
      generateId: () {
        generationCount++;
        return generated;
      },
    );

    expect(await store.loadOrCreate(), generated);
    expect(await store.loadOrCreate(), generated);
    expect(generationCount, 1);
    expect(storage.values[DeviceInstallationIdStore.storageKey], generated);
  });

  test('deletes a corrupt value and safely creates a replacement', () async {
    final storage = _MemoryAuthSecureStorage()
      ..values[DeviceInstallationIdStore.storageKey] = 'hardware-id-or-corrupt';
    final store = DeviceInstallationIdStore(
      storage,
      generateId: () => generated,
    );

    expect(await store.loadOrCreate(), generated);
    expect(storage.deleteCount, 1);
    expect(storage.writeCount, 1);
  });

  test('coalesces concurrent creation into one persisted identifier', () async {
    final storage = _MemoryAuthSecureStorage();
    var generationCount = 0;
    final store = DeviceInstallationIdStore(
      storage,
      generateId: () {
        generationCount++;
        return generated;
      },
    );

    final values = await Future.wait([
      store.loadOrCreate(),
      store.loadOrCreate(),
      store.loadOrCreate(),
    ]);

    expect(values, everyElement(generated));
    expect(generationCount, 1);
    expect(storage.writeCount, 1);
  });

  test('rejects a broken random UUID generator', () async {
    final store = DeviceInstallationIdStore(
      _MemoryAuthSecureStorage(),
      generateId: () => 'not-a-uuid',
    );

    await expectLater(store.loadOrCreate(), throwsStateError);
  });
}

final class _MemoryAuthSecureStorage implements AuthSecureStorage {
  final Map<String, String> values = {};
  int deleteCount = 0;
  int writeCount = 0;

  @override
  Future<void> delete(String key) async {
    deleteCount++;
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    values[key] = value;
  }
}
