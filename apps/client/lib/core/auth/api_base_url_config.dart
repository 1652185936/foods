import 'package:flutter/foundation.dart';

final class ApiBaseUrlConfig {
  ApiBaseUrlConfig._(this.baseUri);

  static const environmentKey = 'ORDIN_API_BASE_URL';
  static final Uri debugDefault = Uri.parse('http://127.0.0.1:8000');

  final Uri baseUri;

  factory ApiBaseUrlConfig.fromEnvironment({
    bool releaseMode = kReleaseMode,
    String configuredUrl = const String.fromEnvironment(environmentKey),
  }) {
    final configured = configuredUrl.trim();
    if (releaseMode && configured.isEmpty) {
      throw StateError(
        '$environmentKey must be explicitly provided for release builds.',
      );
    }

    final uri = configured.isEmpty ? debugDefault : Uri.tryParse(configured);
    if (uri == null || !_isOrigin(uri)) {
      throw ArgumentError.value(
        configuredUrl,
        'configuredUrl',
        'Must be an absolute API origin without credentials, path, query, or fragment.',
      );
    }
    if (releaseMode) {
      if (uri.scheme != 'https') {
        throw ArgumentError.value(
          configuredUrl,
          'configuredUrl',
          'Release API origins must use HTTPS.',
        );
      }
    } else if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' && uri.host == '127.0.0.1')) {
      throw ArgumentError.value(
        configuredUrl,
        'configuredUrl',
        'Debug HTTP is restricted to 127.0.0.1.',
      );
    }
    return ApiBaseUrlConfig._(uri);
  }

  static bool _isOrigin(Uri uri) =>
      uri.isAbsolute &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}
