const localOnlyOwnerUserId = 'local-only';

final class AccountScope {
  const AccountScope.localOnly() : ownerUserId = localOnlyOwnerUserId;

  AccountScope.authenticated(String ownerUserId)
    : ownerUserId = _validate(ownerUserId);

  final String ownerUserId;

  bool get canSync => ownerUserId != localOnlyOwnerUserId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountScope && ownerUserId == other.ownerUserId;

  @override
  int get hashCode => ownerUserId.hashCode;

  static String _validate(String value) {
    final owner = value.trim();
    final canonicalUuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );
    if (owner != value || !canonicalUuid.hasMatch(owner)) {
      throw ArgumentError.value(
        value,
        'ownerUserId',
        'An authenticated account requires a canonical lowercase UUID.',
      );
    }
    return owner;
  }
}

final class LocalOnlySyncDisabledException implements Exception {
  const LocalOnlySyncDisabledException();

  @override
  String toString() => 'Local-only data cannot be synchronized.';
}
