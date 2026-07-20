import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/network/api_client.dart';
import 'package:foods_client/core/network/auth_tokens.dart';

void main() {
  final store = _EmptyTokenStore();

  test('accepts HTTPS origins and local HTTP origins', () {
    for (final uri in [
      Uri.parse('https://api.example.test'),
      Uri.parse('http://localhost:8000'),
      Uri.parse('http://127.0.0.42:8000'),
      Uri.parse('http://[::1]:8000'),
    ]) {
      final clients = OrdinApiClients.create(
        baseUri: uri,
        tokenStore: store,
        loadDeviceInstallationId: () async => 'installation-id',
      );
      expect(clients.meals, same(clients.meals));
      expect(clients.fasting, same(clients.fasting));
      expect(clients.synchronization, same(clients.synchronization));
      clients.close(force: true);
    }
  });

  test('rejects remote HTTP, credentials, and non-origin paths', () {
    for (final uri in [
      Uri.parse('http://api.example.test'),
      Uri.parse('https://user:pass@api.example.test'),
      Uri.parse('https://api.example.test/v1'),
      Uri.parse('https://api.example.test?region=test'),
    ]) {
      expect(
        () => OrdinApiClients.create(
          baseUri: uri,
          tokenStore: store,
          loadDeviceInstallationId: () async => 'installation-id',
        ),
        throwsArgumentError,
      );
    }
  });
}

final class _EmptyTokenStore implements AuthCredentialStore {
  var _epoch = 0;
  var _revision = 0;

  @override
  Future<void> clear() async {
    _epoch++;
    _revision++;
  }

  @override
  Future<bool> clearIfCurrent(AuthCredentialSnapshot expected) async => false;

  @override
  Future<bool> clearCredentialEpoch(int expectedEpoch) async => false;

  @override
  bool isCredentialEpochCurrent(int epoch) => epoch == _epoch;

  @override
  Future<AuthTokens?> read() async => null;

  @override
  Future<AuthCredentialSnapshot> readSnapshot() async =>
      AuthCredentialSnapshot(epoch: _epoch, revision: _revision, tokens: null);

  @override
  Future<void> write(AuthTokens tokens) async {
    _epoch++;
    _revision++;
  }

  @override
  Future<bool> replaceIfCurrent(
    AuthTokens tokens, {
    required AuthCredentialSnapshot expected,
    bool Function()? isOperationCurrent,
  }) async => false;

  @override
  Future<AuthTokens?> writeRefreshedIfCurrent(
    AuthTokens tokens, {
    required AuthCredentialSnapshot expected,
  }) async => null;
}
