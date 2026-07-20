import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/api_base_url_config.dart';

void main() {
  test('debug defaults only to the IPv4 loopback origin', () {
    final config = ApiBaseUrlConfig.fromEnvironment(
      releaseMode: false,
      configuredUrl: '',
    );

    expect(config.baseUri, Uri.parse('http://127.0.0.1:8000'));
  });

  test('release requires an explicit HTTPS origin', () {
    expect(
      () => ApiBaseUrlConfig.fromEnvironment(
        releaseMode: true,
        configuredUrl: '',
      ),
      throwsStateError,
    );
    expect(
      () => ApiBaseUrlConfig.fromEnvironment(
        releaseMode: true,
        configuredUrl: 'http://127.0.0.1:8000',
      ),
      throwsArgumentError,
    );

    final config = ApiBaseUrlConfig.fromEnvironment(
      releaseMode: true,
      configuredUrl: 'https://api.example.test',
    );
    expect(config.baseUri, Uri.parse('https://api.example.test'));
  });

  test('debug permits HTTPS or HTTP on exactly 127.0.0.1', () {
    for (final value in [
      'https://staging.example.test',
      'http://127.0.0.1:9000',
    ]) {
      expect(
        ApiBaseUrlConfig.fromEnvironment(
          releaseMode: false,
          configuredUrl: value,
        ).baseUri,
        Uri.parse(value),
      );
    }

    for (final value in [
      'http://localhost:8000',
      'http://127.0.0.2:8000',
      'http://192.168.1.2:8000',
    ]) {
      expect(
        () => ApiBaseUrlConfig.fromEnvironment(
          releaseMode: false,
          configuredUrl: value,
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects credentials and non-origin URL components', () {
    for (final value in [
      'https://user:pass@api.example.test',
      'https://api.example.test/v1',
      'https://api.example.test?region=test',
      'https://api.example.test#fragment',
    ]) {
      expect(
        () => ApiBaseUrlConfig.fromEnvironment(
          releaseMode: true,
          configuredUrl: value,
        ),
        throwsArgumentError,
      );
    }
  });
}
