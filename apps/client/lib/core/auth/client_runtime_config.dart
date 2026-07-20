import 'package:flutter/foundation.dart';

import '../network/generated/models/client_platform.dart';

final class ClientRuntimeConfig {
  const ClientRuntimeConfig({required this.platform, required this.appVersion});

  static const appVersionEnvironmentKey = 'ORDIN_APP_VERSION';
  static const debugAppVersion = '1.0.0+1';

  final ClientPlatform platform;
  final String appVersion;

  factory ClientRuntimeConfig.fromEnvironment({
    bool releaseMode = kReleaseMode,
    bool web = kIsWeb,
    TargetPlatform? platform,
    String configuredAppVersion = const String.fromEnvironment(
      appVersionEnvironmentKey,
    ),
  }) {
    if (web) {
      throw UnsupportedError('The Ordin client requires a native platform.');
    }
    final appVersion = configuredAppVersion.trim();
    if (releaseMode && appVersion.isEmpty) {
      throw StateError(
        '$appVersionEnvironmentKey must be explicitly provided for release builds.',
      );
    }
    final resolvedVersion = appVersion.isEmpty ? debugAppVersion : appVersion;
    if (resolvedVersion.length > 32 ||
        (configuredAppVersion.isNotEmpty &&
            configuredAppVersion != appVersion)) {
      throw ArgumentError.value(
        configuredAppVersion,
        'configuredAppVersion',
        'Must contain 1 to 32 characters.',
      );
    }
    return ClientRuntimeConfig(
      platform: clientPlatformFor(platform ?? defaultTargetPlatform),
      appVersion: resolvedVersion,
    );
  }
}

ClientPlatform clientPlatformFor(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => ClientPlatform.android,
  TargetPlatform.iOS => ClientPlatform.ios,
  TargetPlatform.windows => ClientPlatform.windows,
  TargetPlatform.macOS => ClientPlatform.macos,
  TargetPlatform.linux || TargetPlatform.fuchsia => throw UnsupportedError(
    'Unsupported Ordin client platform: $platform',
  ),
};
