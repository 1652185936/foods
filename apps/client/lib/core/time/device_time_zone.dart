import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deviceTimeZoneProvider = Provider<DeviceTimeZone>(
  (ref) => const FlutterDeviceTimeZone(),
);

final initialTimeZoneIdProvider = Provider<String>((ref) {
  throw StateError('The initial device time zone must be provided at startup.');
}, dependencies: const []);

final currentTimeZoneStateProvider =
    NotifierProvider<CurrentTimeZoneController, String>(
      CurrentTimeZoneController.new,
      dependencies: [initialTimeZoneIdProvider],
    );

final currentTimeZoneIdProvider = Provider<String>(
  (ref) => ref.watch(currentTimeZoneStateProvider),
  dependencies: [currentTimeZoneStateProvider],
);

final class CurrentTimeZoneController extends Notifier<String> {
  @override
  String build() => ref.watch(initialTimeZoneIdProvider);

  bool updateIdentifier(String identifier) {
    final next = identifier.trim();
    if (next.isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'The device time-zone identifier cannot be empty.',
      );
    }
    if (next == state) {
      return false;
    }
    state = next;
    return true;
  }
}

abstract interface class DeviceTimeZone {
  Future<String> currentIdentifier();
}

final class FlutterDeviceTimeZone implements DeviceTimeZone {
  const FlutterDeviceTimeZone();

  @override
  Future<String> currentIdentifier() async {
    final zone = await FlutterTimezone.getLocalTimezone();
    final identifier = zone.identifier.trim();
    if (identifier.isEmpty) {
      throw StateError('The device returned an empty time-zone identifier.');
    }
    return identifier;
  }
}

final class FixedDeviceTimeZone implements DeviceTimeZone {
  const FixedDeviceTimeZone(this.identifier);

  final String identifier;

  @override
  Future<String> currentIdentifier() async => identifier;
}
