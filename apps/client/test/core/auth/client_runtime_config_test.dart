import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/client_runtime_config.dart';
import 'package:foods_client/core/network/generated/models/client_platform.dart';

void main() {
  test('maps all supported native targets', () {
    expect(clientPlatformFor(TargetPlatform.android), ClientPlatform.android);
    expect(clientPlatformFor(TargetPlatform.iOS), ClientPlatform.ios);
    expect(clientPlatformFor(TargetPlatform.windows), ClientPlatform.windows);
    expect(clientPlatformFor(TargetPlatform.macOS), ClientPlatform.macos);
  });

  test('rejects unsupported native and web targets', () {
    expect(
      () => clientPlatformFor(TargetPlatform.linux),
      throwsUnsupportedError,
    );
    expect(
      () => ClientRuntimeConfig.fromEnvironment(web: true, releaseMode: false),
      throwsUnsupportedError,
    );
  });

  test('release requires an explicit app version', () {
    expect(
      () => ClientRuntimeConfig.fromEnvironment(
        releaseMode: true,
        web: false,
        platform: TargetPlatform.android,
        configuredAppVersion: '',
      ),
      throwsStateError,
    );

    final config = ClientRuntimeConfig.fromEnvironment(
      releaseMode: true,
      web: false,
      platform: TargetPlatform.windows,
      configuredAppVersion: '2.3.0+45',
    );
    expect(config.appVersion, '2.3.0+45');
    expect(config.platform, ClientPlatform.windows);
  });

  test('debug uses the declared safe development version', () {
    final config = ClientRuntimeConfig.fromEnvironment(
      releaseMode: false,
      web: false,
      platform: TargetPlatform.android,
      configuredAppVersion: '',
    );

    expect(config.appVersion, ClientRuntimeConfig.debugAppVersion);
  });
}
