import '../network/auth_tokens.dart';

final class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.expiresAtUtc,
    required this.resendAfter,
  });

  final String id;
  final DateTime expiresAtUtc;
  final Duration resendAfter;
}

final class AuthSession {
  const AuthSession({
    required this.userId,
    required this.nickname,
    required this.userVersion,
    required this.tokens,
  });

  final String userId;
  final String? nickname;
  final int userVersion;
  final AuthTokens tokens;
}

/// The minimum server-confirmed identity needed to restore an account scope
/// while the device is temporarily offline.
final class CachedAuthIdentity {
  const CachedAuthIdentity({
    required this.userId,
    required this.nickname,
    required this.userVersion,
  });

  factory CachedAuthIdentity.fromSession(AuthSession session) =>
      CachedAuthIdentity(
        userId: session.userId,
        nickname: session.nickname,
        userVersion: session.userVersion,
      );

  final String userId;
  final String? nickname;
  final int userVersion;
}

/// Credential persistence with an identity cache bound to the same account
/// epoch as its token pair.
abstract interface class AuthSessionCredentialStore
    implements AuthCredentialStore {
  Future<CachedAuthIdentity?> readCachedIdentity(
    AuthCredentialSnapshot expected,
  );

  /// Updates identity for [expectedEpoch] while preserving the latest refresh
  /// revision in that account epoch. The returned snapshot is the exact token
  /// revision written alongside the identity.
  Future<AuthCredentialSnapshot?> cacheIdentityForCredentialEpoch(
    CachedAuthIdentity identity, {
    required int expectedEpoch,
  });

  /// Replaces both the token pair and its server-confirmed identity as one
  /// persisted credential record.
  Future<bool> replaceSessionIfCurrent(
    AuthTokens tokens,
    CachedAuthIdentity identity, {
    required AuthCredentialSnapshot expected,
    bool Function()? isOperationCurrent,
  });
}
