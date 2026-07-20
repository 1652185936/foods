import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/fasting/application/fasting_controller.dart';
import '../sync/sync_coordinator.dart';
import '../time/device_time_zone.dart';
import '../time/local_day.dart';

final timeZonePollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 1),
);

class AppLifecycleCoordinator extends ConsumerStatefulWidget {
  const AppLifecycleCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLifecycleCoordinator> createState() =>
      _AppLifecycleCoordinatorState();
}

class _AppLifecycleCoordinatorState
    extends ConsumerState<AppLifecycleCoordinator>
    with WidgetsBindingObserver {
  Timer? _timeZonePoll;
  bool _reconciling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final interval = ref.read(timeZonePollIntervalProvider);
    if (interval > Duration.zero) {
      _timeZonePoll = Timer.periodic(
        interval,
        (_) => unawaited(_refreshTimeZone()),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_reconcileForegroundState());
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        ref.read(syncCoordinatorProvider.notifier).onAppBackgrounded();
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeZonePoll?.cancel();
    super.dispose();
  }

  Future<void> _reconcileForegroundState() async {
    if (_reconciling) {
      return;
    }
    _reconciling = true;
    try {
      try {
        await _refreshTimeZone();
        ref.read(currentLocalDayProvider.notifier).refresh();
        await ref.read(fastingProvider.future);
        await ref.read(fastingProvider.notifier).refresh();
      } catch (_) {
        // The feature controllers retain their last usable state on refresh.
      }
      await ref.read(syncCoordinatorProvider.notifier).onAppResumed();
    } finally {
      _reconciling = false;
    }
  }

  Future<void> _refreshTimeZone() async {
    try {
      final identifier = await ref
          .read(deviceTimeZoneProvider)
          .currentIdentifier();
      ref
          .read(currentTimeZoneStateProvider.notifier)
          .updateIdentifier(identifier);
    } catch (_) {
      // Keep the last valid IANA zone when the platform lookup is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fastingProvider);
    ref.watch(syncCoordinatorProvider);
    return widget.child;
  }
}
