import 'generated/models/token_pair_response.dart';

const authRequiredCredentialEpochExtraKey =
    'ordin.auth.required-credential-epoch';

/// Tokens persisted as one atomic refresh-rotation unit.
final class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.tokenType,
  });

  factory AuthTokens.fromResponse(TokenPairResponse response, {DateTime? now}) {
    final checkedAt = now ?? DateTime.now();
    if (response.tokenType.toLowerCase() != 'bearer') {
      throw const FormatException('Unsupported token type; expected Bearer.');
    }
    if (!_isValidToken(response.accessToken) ||
        !_isValidToken(response.refreshToken)) {
      throw const FormatException(
        'Access and refresh tokens must be non-empty.',
      );
    }
    if (!response.accessTokenExpiresAt.isAfter(checkedAt)) {
      throw const FormatException('Access token is already expired.');
    }
    if (!response.refreshTokenExpiresAt.isAfter(
      response.accessTokenExpiresAt,
    )) {
      throw const FormatException(
        'Refresh token must outlive the access token.',
      );
    }

    return AuthTokens(
      accessToken: response.accessToken,
      accessTokenExpiresAt: response.accessTokenExpiresAt,
      refreshToken: response.refreshToken,
      refreshTokenExpiresAt: response.refreshTokenExpiresAt,
      tokenType: 'Bearer',
    );
  }

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final String tokenType;

  static bool _isValidToken(String value) =>
      value.isNotEmpty && !RegExp(r'\s').hasMatch(value);
}

/// A process-local identity for one observed credential revision.
///
/// [epoch] changes when credentials are replaced or cleared. [revision]
/// additionally changes after a refresh rotation, allowing late refresh
/// responses and failures to use compare-and-swap semantics.
final class AuthCredentialSnapshot {
  const AuthCredentialSnapshot({
    required this.epoch,
    required this.revision,
    required this.tokens,
  });

  final int epoch;
  final int revision;
  final AuthTokens? tokens;
}

/// Storage implementations must replace the full token pair atomically.
abstract interface class AuthTokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

/// Extends token persistence with account-epoch and refresh-CAS guarantees.
abstract interface class AuthCredentialStore implements AuthTokenStore {
  Future<AuthCredentialSnapshot> readSnapshot();

  bool isCredentialEpochCurrent(int epoch);

  /// Replaces credentials only if [expected] is still the exact revision.
  Future<bool> replaceIfCurrent(
    AuthTokens tokens, {
    required AuthCredentialSnapshot expected,
    bool Function()? isOperationCurrent,
  });

  /// Commits a refresh only if [expected] is still the current revision.
  ///
  /// A same-epoch winner is returned when another refresh already rotated the
  /// pair. `null` means the credentials were cleared or replaced.
  Future<AuthTokens?> writeRefreshedIfCurrent(
    AuthTokens tokens, {
    required AuthCredentialSnapshot expected,
  });

  /// Clears only the exact credential revision observed by the caller.
  Future<bool> clearIfCurrent(AuthCredentialSnapshot expected);

  /// Clears any refresh revision that still belongs to [expectedEpoch].
  Future<bool> clearCredentialEpoch(int expectedEpoch);
}

/// Refreshes and persists a rotated token pair using an unauthenticated client.
abstract interface class AccessTokenRefresher {
  Future<AuthTokens?> refreshAccessToken({required int expectedEpoch});
}

typedef DeviceInstallationIdLoader = Future<String> Function();
