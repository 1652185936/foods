import '../network/generated/authentication/authentication_api.dart';
import '../network/generated/models/auth_session_response.dart';
import '../network/generated/models/otp_challenge_input.dart';
import '../network/generated/models/otp_challenge_response.dart';
import '../network/generated/models/otp_verification_input.dart';
import '../network/generated/models/refresh_token_input.dart';
import '../network/generated/models/token_pair_response.dart';
import '../network/generated/models/user_response.dart';
import '../network/generated/users/users_api.dart';
import '../network/auth_tokens.dart';

abstract interface class AuthRemoteApi {
  Future<OtpChallengeResponse> createOtpChallenge({
    required OtpChallengeInput body,
    required String idempotencyKey,
  });

  Future<AuthSessionResponse> verifyOtpChallenge({
    required String challengeId,
    required OtpVerificationInput body,
  });

  Future<TokenPairResponse> refreshAuthToken({required RefreshTokenInput body});

  Future<void> deleteCurrentSession({required int expectedCredentialEpoch});

  Future<UserResponse> getCurrentUser();
}

final class GeneratedAuthRemoteApi implements AuthRemoteApi {
  const GeneratedAuthRemoteApi(
    this._publicAuthentication,
    this._authenticatedAuthentication,
    this._users,
  );

  final AuthenticationApi _publicAuthentication;
  final AuthenticationApi _authenticatedAuthentication;
  final UsersApi _users;

  @override
  Future<OtpChallengeResponse> createOtpChallenge({
    required OtpChallengeInput body,
    required String idempotencyKey,
  }) => _publicAuthentication.createOtpChallenge(
    body: body,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<AuthSessionResponse> verifyOtpChallenge({
    required String challengeId,
    required OtpVerificationInput body,
  }) => _publicAuthentication.verifyOtpChallenge(
    challengeId: challengeId,
    body: body,
  );

  @override
  Future<TokenPairResponse> refreshAuthToken({
    required RefreshTokenInput body,
  }) => _publicAuthentication.refreshAuthToken(body: body);

  @override
  Future<void> deleteCurrentSession({required int expectedCredentialEpoch}) =>
      _authenticatedAuthentication.deleteCurrentSession(
        extras: <String, dynamic>{
          ...AuthenticationApi.deleteCurrentSessionOpenapiExtras,
          authRequiredCredentialEpochExtraKey: expectedCredentialEpoch,
        },
      );

  @override
  Future<UserResponse> getCurrentUser() => _users.getCurrentUser();
}
