import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/auth_tokens.dart';
import 'api_base_url_config.dart';
import 'auth_remote_api.dart';
import 'auth_repository.dart';
import 'auth_secure_storage.dart';
import 'client_runtime_config.dart';
import 'device_installation_id_store.dart';
import 'secure_auth_token_store.dart';

final apiBaseUrlConfigProvider = Provider<ApiBaseUrlConfig>(
  (ref) => ApiBaseUrlConfig.fromEnvironment(),
);

final clientRuntimeConfigProvider = Provider<ClientRuntimeConfig>(
  (ref) => ClientRuntimeConfig.fromEnvironment(),
);

final authSecureStorageProvider = Provider<AuthSecureStorage>(
  (ref) => FlutterAuthSecureStorage(),
);

final secureAuthTokenStoreProvider = Provider<SecureAuthTokenStore>((ref) {
  final store = SecureAuthTokenStore(ref.watch(authSecureStorageProvider));
  ref.onDispose(() => unawaited(store.dispose()));
  return store;
}, dependencies: [authSecureStorageProvider]);

final authTokenStoreProvider = Provider<AuthTokenStore>(
  (ref) => ref.watch(secureAuthTokenStoreProvider),
  dependencies: [secureAuthTokenStoreProvider],
);

final authSessionClearedEventsProvider = Provider<Stream<void>>(
  (ref) => ref.watch(secureAuthTokenStoreProvider).cleared,
  dependencies: [secureAuthTokenStoreProvider],
);

final deviceInstallationIdStoreProvider = Provider<DeviceInstallationIdStore>(
  (ref) => DeviceInstallationIdStore(ref.watch(authSecureStorageProvider)),
  dependencies: [authSecureStorageProvider],
);

final ordinApiClientsProvider = Provider<OrdinApiClients>(
  (ref) {
    final clients = OrdinApiClients.create(
      baseUri: ref.watch(apiBaseUrlConfigProvider).baseUri,
      tokenStore: ref.watch(secureAuthTokenStoreProvider),
      loadDeviceInstallationId: ref
          .watch(deviceInstallationIdStoreProvider)
          .loadOrCreate,
    );
    ref.onDispose(() => clients.close(force: true));
    return clients;
  },
  dependencies: [
    apiBaseUrlConfigProvider,
    secureAuthTokenStoreProvider,
    deviceInstallationIdStoreProvider,
  ],
);

final authRemoteApiProvider = Provider<AuthRemoteApi>((ref) {
  final clients = ref.watch(ordinApiClientsProvider);
  return GeneratedAuthRemoteApi(
    clients.publicAuthentication,
    clients.authenticatedAuthentication,
    clients.users,
  );
}, dependencies: [ordinApiClientsProvider]);

final authSessionRepositoryProvider = Provider<AuthSessionRepository>(
  (ref) {
    final runtime = ref.watch(clientRuntimeConfigProvider);
    return AuthRepository(
      ref.watch(authRemoteApiProvider),
      ref.watch(secureAuthTokenStoreProvider),
      ref.watch(deviceInstallationIdStoreProvider),
      platform: runtime.platform,
      appVersion: runtime.appVersion,
    );
  },
  dependencies: [
    clientRuntimeConfigProvider,
    authRemoteApiProvider,
    secureAuthTokenStoreProvider,
    deviceInstallationIdStoreProvider,
  ],
);
