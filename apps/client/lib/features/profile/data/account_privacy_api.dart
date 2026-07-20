import '../../../core/network/generated/models/account_data_export_response.dart';
import '../../../core/network/generated/models/account_deletion_input.dart';
import '../../../core/network/generated/users/users_api.dart';

const accountDeletionBackendConfirmation = 'DELETE_MY_ACCOUNT';

abstract interface class AccountPrivacyApi {
  Future<AccountDataExportResponse> exportCurrentUserData();

  Future<void> deleteCurrentUser({
    required String refreshToken,
    required String deviceInstallationId,
  });
}

final class GeneratedAccountPrivacyApi implements AccountPrivacyApi {
  const GeneratedAccountPrivacyApi(this._usersApi);

  final UsersApi _usersApi;

  @override
  Future<AccountDataExportResponse> exportCurrentUserData() =>
      _usersApi.exportCurrentUserData();

  @override
  Future<void> deleteCurrentUser({
    required String refreshToken,
    required String deviceInstallationId,
  }) {
    return _usersApi.deleteCurrentUser(
      body: AccountDeletionInput(
        confirmation: accountDeletionBackendConfirmation,
        deviceInstallationId: deviceInstallationId,
        refreshToken: refreshToken,
      ),
    );
  }
}
