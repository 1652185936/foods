import 'package:flutter_riverpod/flutter_riverpod.dart';

final appClockProvider = Provider<AppClock>(
  (ref) => const SystemAppClock(),
  dependencies: const [],
);

abstract interface class AppClock {
  DateTime now();
}

final class SystemAppClock implements AppClock {
  const SystemAppClock();

  @override
  DateTime now() => DateTime.now();
}

final class FixedAppClock implements AppClock {
  const FixedAppClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}
