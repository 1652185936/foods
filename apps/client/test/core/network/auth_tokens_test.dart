import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/network/auth_tokens.dart';
import 'package:foods_client/core/network/generated/models/token_pair_response.dart';

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  test('accepts a valid Bearer token pair', () {
    final tokens = AuthTokens.fromResponse(_response(now), now: now);

    expect(tokens.accessToken, 'access');
    expect(tokens.tokenType, 'Bearer');
  });

  test('rejects unsupported token types and malformed token values', () {
    expect(
      () =>
          AuthTokens.fromResponse(_response(now, tokenType: 'Basic'), now: now),
      throwsFormatException,
    );
    expect(
      () => AuthTokens.fromResponse(_response(now, accessToken: ''), now: now),
      throwsFormatException,
    );
    expect(
      () => AuthTokens.fromResponse(
        _response(now, refreshToken: 'refresh\nvalue'),
        now: now,
      ),
      throwsFormatException,
    );
  });

  test('rejects expired or inverted expiry windows', () {
    expect(
      () => AuthTokens.fromResponse(
        _response(now, accessExpiresAt: now),
        now: now,
      ),
      throwsFormatException,
    );
    expect(
      () => AuthTokens.fromResponse(
        _response(now, refreshExpiresAt: now.add(const Duration(minutes: 30))),
        now: now,
      ),
      throwsFormatException,
    );
  });
}

TokenPairResponse _response(
  DateTime now, {
  String accessToken = 'access',
  String refreshToken = 'refresh',
  String tokenType = 'Bearer',
  DateTime? accessExpiresAt,
  DateTime? refreshExpiresAt,
}) => TokenPairResponse(
  accessToken: accessToken,
  accessTokenExpiresAt: accessExpiresAt ?? now.add(const Duration(hours: 1)),
  refreshToken: refreshToken,
  refreshTokenExpiresAt: refreshExpiresAt ?? now.add(const Duration(days: 30)),
  tokenType: tokenType,
);
