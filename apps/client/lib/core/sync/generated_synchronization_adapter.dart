import 'package:dio/dio.dart';

import '../network/generated/export.dart' as api;
import '../network/problem_details_mapper.dart';
import 'sync_models.dart';
import 'synchronization_adapter.dart';

final class GeneratedSynchronizationAdapter implements SynchronizationAdapter {
  const GeneratedSynchronizationAdapter(this._api);

  final api.SynchronizationApi _api;

  @override
  Future<SyncWriteReceipt> push(PendingSyncOperation operation) async {
    _validateOperation(operation);
    late final api.SyncPushResponse response;
    try {
      response = await _api.pushSyncOperations(
        body: api.SyncPushInput(
          operations: <api.SyncOperationInput>[_toApiOperation(operation)],
        ),
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final problem = mapProblemDetails(error);
      if ((statusCode == 400 || statusCode == 422) &&
          problem?.problem.status == statusCode) {
        throw RejectedSyncOperationException(
          statusCode: statusCode!,
          problemCode: problem!.problem.code,
        );
      }
      rethrow;
    }
    if (response.results.length != 1) {
      throw StateError('A single sync operation must return one result.');
    }
    final result = response.results.single;
    if (result.operationId != operation.operationId ||
        result.entityId != operation.entityId ||
        _entityFromApi(result.entityType) != operation.entityType) {
      throw StateError(
        'The sync result does not match the requested operation.',
      );
    }
    _validateWriteResult(result);
    return SyncWriteReceipt(
      operationId: result.operationId,
      entityType: _entityFromApi(result.entityType),
      entityId: result.entityId,
      disposition: _dispositionFromApi(result.status),
      replayed: result.replayed,
      serverVersion: result.serverVersion,
      changeCursor: result.changeCursor,
    );
  }

  @override
  Future<SyncPullPage> pull({required int cursor, required int limit}) async {
    if (cursor < 0) {
      throw ArgumentError.value(cursor, 'cursor', 'Cannot be negative.');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be from 1 to 100.');
    }
    final response = await _api.pullSyncChanges(cursor: cursor, limit: limit);
    if (response.nextCursor < cursor) {
      throw StateError('The server returned a backwards sync cursor.');
    }
    final changes = <RemoteSyncChange>[];
    var previousCursor = cursor;
    for (final rawChange in response.changes) {
      final change = _changeFromApi(rawChange);
      if (change.changeCursor <= previousCursor ||
          change.changeCursor > response.nextCursor) {
        throw StateError('Sync changes must have strictly increasing cursors.');
      }
      previousCursor = change.changeCursor;
      changes.add(change);
    }
    if (response.hasMore && response.nextCursor <= cursor) {
      throw StateError('A paginated sync response did not advance its cursor.');
    }
    return SyncPullPage(
      changes: changes,
      nextCursor: response.nextCursor,
      hasMore: response.hasMore,
    );
  }

  void _validateOperation(PendingSyncOperation operation) {
    _canonicalUuid(operation.operationId, 'operationId');
    if (operation.entityType == SyncEntityKind.appPreferences) {
      if (operation.entityId != 'current') {
        throw StateError('appPreferences entityId must be current.');
      }
      if (operation.action == SyncOperationAction.delete) {
        throw StateError('appPreferences cannot be deleted.');
      }
    } else {
      _canonicalUuid(operation.entityId, 'entityId');
    }
    if (operation.expectedVersion < 0 || operation.payloadVersion != 1) {
      throw StateError('The sync operation version fields are invalid.');
    }
  }

  void _validateWriteResult(api.SyncWriteResultResponse result) {
    switch (result.status) {
      case api.SyncWriteStatus.applied:
      case api.SyncWriteStatus.versionConflict:
        if ((result.serverVersion ?? 0) <= 0 ||
            (result.changeCursor ?? 0) <= 0) {
          throw StateError(
            '${result.status} requires a positive version and cursor.',
          );
        }
      case api.SyncWriteStatus.notFound:
      case api.SyncWriteStatus.idempotencyConflict:
      case api.SyncWriteStatus.activeFastingConflict:
        if (result.serverVersion != null || result.changeCursor != null) {
          throw StateError(
            '${result.status} cannot include a version or cursor.',
          );
        }
      case api.SyncWriteStatus.$unknown:
        throw StateError('The server returned an unknown sync write status.');
    }
  }

  api.SyncOperationInput _toApiOperation(PendingSyncOperation operation) {
    final isDelete = operation.action == SyncOperationAction.delete;
    final payload = isDelete ? null : operation.payload;
    if (!isDelete && payload == null) {
      throw StateError('An upsert operation requires a payload.');
    }
    return api.SyncOperationInput(
      action: switch (operation.action) {
        SyncOperationAction.upsert => api.SyncAction.upsert,
        SyncOperationAction.delete => api.SyncAction.delete,
      },
      entityId: operation.entityId,
      entityType: _entityToApi(operation.entityType),
      expectedVersion: operation.expectedVersion,
      operationId: operation.operationId,
      payloadVersion: operation.payloadVersion,
      appPreferences:
          payload != null &&
              operation.entityType == SyncEntityKind.appPreferences
          ? _preferencesPayload(payload)
          : null,
      fastingSession:
          payload != null &&
              operation.entityType == SyncEntityKind.fastingSession
          ? _fastingPayload(payload)
          : null,
      meal: payload != null && operation.entityType == SyncEntityKind.mealLog
          ? _mealPayload(payload)
          : null,
    );
  }

  api.MealSyncPayload _mealPayload(Map<String, Object?> payload) {
    final rawItems = _list(payload, 'items');
    return api.MealSyncPayload(
      isWithinEatingWindow: _bool(payload, 'isWithinEatingWindow'),
      items: rawItems
          .map((raw) {
            final item = _map(raw, 'items[]');
            return api.MealItemInputModel(
              carbsMg: _int(item, 'carbsMg'),
              energyKcal: _int(item, 'energyKcal'),
              fatMg: _int(item, 'fatMg'),
              id: _canonicalUuid(_string(item, 'id'), 'items[].id'),
              imageReference: _safeObjectKey(item['imageReference']),
              name: _string(item, 'name'),
              proteinMg: _int(item, 'proteinMg'),
              servingMilli: _int(item, 'servingMilli'),
            );
          })
          .toList(growable: false),
      localDay: _string(payload, 'localDay'),
      occurredAtUtc: _dateTime(payload, 'occurredAtUtc'),
      source: _mealSource(_string(payload, 'source')),
      timeZoneId: _timeZoneId(payload),
      type: _mealType(_string(payload, 'type')),
    );
  }

  api.FastingSessionSyncPayload _fastingPayload(Map<String, Object?> payload) {
    return api.FastingSessionSyncPayload(
      plan: _fastingPlan(_string(payload, 'plan')),
      startedAtUtc: _dateTime(payload, 'startedAtUtc'),
      startedLocalDay: _string(payload, 'startedLocalDay'),
      status: _fastingStatus(_string(payload, 'status')),
      targetEndAtUtc: _dateTime(payload, 'targetEndAtUtc'),
      targetEndLocalDay: _string(payload, 'targetEndLocalDay'),
      timeZoneId: _timeZoneId(payload),
      endedAtUtc: _nullableDateTime(payload['endedAtUtc']),
      endedLocalDay: payload['endedLocalDay'] as String?,
    );
  }

  api.AppPreferencesSyncPayload _preferencesPayload(
    Map<String, Object?> payload,
  ) {
    return api.AppPreferencesSyncPayload(
      dailyEnergyTargetKcal: _int(payload, 'dailyEnergyTargetKcal'),
      fastingReminderEnabled: _bool(payload, 'fastingReminderEnabled'),
      selectedFastingPlan: _fastingPlan(
        _string(payload, 'selectedFastingPlan'),
      ),
    );
  }

  RemoteSyncChange _changeFromApi(api.SyncChangeResponse change) {
    if (change.changeCursor <= 0 || change.version <= 0) {
      throw StateError('A sync change requires a positive cursor and version.');
    }
    final entityType = _entityFromApi(change.entityType);
    if (entityType == SyncEntityKind.appPreferences) {
      if (change.entityId != 'current') {
        throw StateError('appPreferences entityId must be current.');
      }
    } else {
      _canonicalUuid(change.entityId, 'entityId');
    }
    final payloadCount = <Object?>[
      change.meal,
      change.fastingSession,
      change.appPreferences,
    ].where((payload) => payload != null).length;
    if (change.deletedAtUtc != null) {
      if (payloadCount != 0 || entityType == SyncEntityKind.appPreferences) {
        throw StateError('A tombstone cannot include an entity payload.');
      }
      _requireUtc(change.deletedAtUtc!, 'deletedAtUtc');
    } else if (payloadCount != 1) {
      throw StateError('A sync change requires exactly one entity payload.');
    }
    final payload = switch (entityType) {
      SyncEntityKind.mealLog =>
        change.meal == null ? null : _checkedMealPayload(change, change.meal!),
      SyncEntityKind.fastingSession =>
        change.fastingSession == null
            ? null
            : _checkedFastingPayload(change, change.fastingSession!),
      SyncEntityKind.appPreferences =>
        change.appPreferences == null
            ? null
            : _checkedPreferencesPayload(change, change.appPreferences!),
    };
    if (change.deletedAtUtc == null && payload == null) {
      throw StateError('A non-tombstone sync change requires a payload.');
    }
    return RemoteSyncChange(
      changeCursor: change.changeCursor,
      entityType: entityType,
      entityId: change.entityId,
      version: change.version,
      deletedAtUtc: change.deletedAtUtc,
      payload: payload,
    );
  }

  Map<String, Object?> _checkedMealPayload(
    api.SyncChangeResponse change,
    api.MealResponse meal,
  ) {
    if (change.fastingSession != null ||
        change.appPreferences != null ||
        meal.id != change.entityId ||
        meal.version != change.version ||
        meal.changeCursor != change.changeCursor) {
      throw StateError('The meal payload does not match its sync change.');
    }
    return _mealResponsePayload(meal);
  }

  Map<String, Object?> _checkedFastingPayload(
    api.SyncChangeResponse change,
    api.FastingSessionResponse fasting,
  ) {
    if (change.meal != null ||
        change.appPreferences != null ||
        fasting.id != change.entityId ||
        fasting.version != change.version ||
        fasting.changeCursor != change.changeCursor) {
      throw StateError('The fasting payload does not match its sync change.');
    }
    return _fastingResponsePayload(fasting);
  }

  Map<String, Object?> _checkedPreferencesPayload(
    api.SyncChangeResponse change,
    api.AppPreferencesResponse preferences,
  ) {
    if (change.meal != null ||
        change.fastingSession != null ||
        preferences.version != change.version ||
        preferences.changeCursor != change.changeCursor) {
      throw StateError(
        'The preferences payload does not match its sync change.',
      );
    }
    return _preferencesResponsePayload(preferences);
  }

  Map<String, Object?> _mealResponsePayload(api.MealResponse meal) {
    return <String, Object?>{
      'id': meal.id,
      'type': _knownJson(meal.type.json, 'meal type'),
      'source': _knownJson(meal.source.json, 'meal source'),
      'occurredAtUtc': _requireUtc(meal.occurredAtUtc, 'occurredAtUtc'),
      'timeZoneId': meal.timeZoneId,
      'localDay': meal.localDay,
      'isWithinEatingWindow': meal.isWithinEatingWindow,
      'items': meal.items
          .map(
            (item) => <String, Object?>{
              'id': item.id,
              'name': item.name,
              'servingMilli': item.servingMilli,
              'energyKcal': item.energyKcal,
              'proteinMg': item.proteinMg,
              'carbsMg': item.carbsMg,
              'fatMg': item.fatMg,
              'imageReference': _safeObjectKey(item.imageReference),
            },
          )
          .toList(growable: false),
      'createdAtUtc': _requireUtc(meal.createdAtUtc, 'createdAtUtc'),
      'updatedAtUtc': _requireUtc(meal.updatedAtUtc, 'updatedAtUtc'),
    };
  }

  Map<String, Object?> _fastingResponsePayload(
    api.FastingSessionResponse fasting,
  ) {
    return <String, Object?>{
      'id': fasting.id,
      'plan': _knownJson(fasting.plan.json, 'fasting plan'),
      'status': _knownJson(fasting.status.json, 'fasting status'),
      'startedAtUtc': _requireUtc(fasting.startedAtUtc, 'startedAtUtc'),
      'targetEndAtUtc': _requireUtc(fasting.targetEndAtUtc, 'targetEndAtUtc'),
      'endedAtUtc': fasting.endedAtUtc == null
          ? null
          : _requireUtc(fasting.endedAtUtc!, 'endedAtUtc'),
      'timeZoneId': fasting.timeZoneId,
      'startedLocalDay': fasting.startedLocalDay,
      'targetEndLocalDay': fasting.targetEndLocalDay,
      'endedLocalDay': fasting.endedLocalDay,
      'createdAtUtc': _requireUtc(fasting.createdAtUtc, 'createdAtUtc'),
      'updatedAtUtc': _requireUtc(fasting.updatedAtUtc, 'updatedAtUtc'),
    };
  }

  Map<String, Object?> _preferencesResponsePayload(
    api.AppPreferencesResponse preferences,
  ) {
    return <String, Object?>{
      'dailyEnergyTargetKcal': preferences.dailyEnergyTargetKcal,
      'selectedFastingPlan': _knownJson(
        preferences.selectedFastingPlan.json,
        'fasting plan',
      ),
      'fastingReminderEnabled': preferences.fastingReminderEnabled,
      'createdAtUtc': _requireUtc(preferences.createdAtUtc, 'createdAtUtc'),
      'updatedAtUtc': _requireUtc(preferences.updatedAtUtc, 'updatedAtUtc'),
    };
  }

  static api.SyncEntityType _entityToApi(SyncEntityKind entity) =>
      switch (entity) {
        SyncEntityKind.mealLog => api.SyncEntityType.mealLog,
        SyncEntityKind.fastingSession => api.SyncEntityType.fastingSession,
        SyncEntityKind.appPreferences => api.SyncEntityType.appPreferences,
      };

  static SyncEntityKind _entityFromApi(api.SyncEntityType entity) =>
      switch (entity) {
        api.SyncEntityType.mealLog => SyncEntityKind.mealLog,
        api.SyncEntityType.fastingSession => SyncEntityKind.fastingSession,
        api.SyncEntityType.appPreferences => SyncEntityKind.appPreferences,
        api.SyncEntityType.$unknown => throw StateError(
          'Unknown sync entity type.',
        ),
      };

  static SyncWriteDisposition _dispositionFromApi(api.SyncWriteStatus status) =>
      switch (status) {
        api.SyncWriteStatus.applied => SyncWriteDisposition.applied,
        api.SyncWriteStatus.versionConflict =>
          SyncWriteDisposition.versionConflict,
        api.SyncWriteStatus.notFound => SyncWriteDisposition.notFound,
        api.SyncWriteStatus.idempotencyConflict =>
          SyncWriteDisposition.idempotencyConflict,
        api.SyncWriteStatus.activeFastingConflict =>
          SyncWriteDisposition.activeFastingConflict,
        api.SyncWriteStatus.$unknown => throw StateError(
          'Unknown sync write status.',
        ),
      };

  static api.MealType _mealType(String value) {
    final parsed = api.MealType.fromJson(value);
    if (parsed == api.MealType.$unknown) {
      throw FormatException('Unknown meal type $value.');
    }
    return parsed;
  }

  static api.MealSource _mealSource(String value) {
    final parsed = api.MealSource.fromJson(value);
    if (parsed == api.MealSource.$unknown) {
      throw FormatException('Unknown meal source $value.');
    }
    return parsed;
  }

  static api.FastingPlan _fastingPlan(String value) {
    final parsed = api.FastingPlan.fromJson(value);
    if (parsed == api.FastingPlan.$unknown) {
      throw FormatException('Unknown fasting plan $value.');
    }
    return parsed;
  }

  static api.FastingSessionStatus _fastingStatus(String value) {
    final parsed = api.FastingSessionStatus.fromJson(value);
    if (parsed == api.FastingSessionStatus.$unknown) {
      throw FormatException('Unknown fasting status $value.');
    }
    return parsed;
  }

  static String? _safeObjectKey(Object? value) {
    if (value is! String || value.isEmpty || value != value.trim()) {
      return null;
    }
    final lower = value.toLowerCase();
    if (value.startsWith('/') ||
        value.contains(r'\') ||
        lower.startsWith('assets/') ||
        lower.startsWith('file:') ||
        Uri.tryParse(value)?.hasScheme == true) {
      return null;
    }
    final segments = value.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      return null;
    }
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]{0,511}$').hasMatch(value)
        ? value
        : null;
  }

  static String _knownJson(String? value, String label) {
    if (value == null) {
      throw StateError('Unknown $label.');
    }
    return value;
  }

  static Map<String, Object?> _map(Object? value, String label) {
    if (value is! Map) {
      throw FormatException('$label must be an object.');
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static List<Object?> _list(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! List) {
      throw FormatException('$key must be a list.');
    }
    return value.cast<Object?>();
  }

  static String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static String _timeZoneId(Map<String, Object?> payload) {
    final identifier = _string(payload, 'timeZoneId').trim();
    if (identifier.isEmpty) {
      throw const FormatException('timeZoneId must be non-empty.');
    }
    return switch (identifier) {
      'GMT' || 'Etc/GMT' => 'UTC',
      _ => identifier,
    };
  }

  static int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw FormatException('$key must be an integer.');
    }
    return value;
  }

  static bool _bool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! bool) {
      throw FormatException('$key must be a boolean.');
    }
    return value;
  }

  static DateTime _dateTime(Map<String, Object?> map, String key) {
    final value = _nullableDateTime(map[key]);
    if (value == null) {
      throw FormatException('$key must be a date-time.');
    }
    return value;
  }

  static DateTime? _nullableDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      if (!value.isUtc) {
        throw const FormatException('Expected a UTC date-time value.');
      }
      return value;
    }
    if (value is String) {
      if (!(value.endsWith('Z') || value.endsWith('+00:00'))) {
        throw const FormatException(
          'Expected a date-time with a zero UTC offset.',
        );
      }
      final parsed = DateTime.tryParse(value);
      if (parsed == null || !parsed.isUtc) {
        throw const FormatException('Expected a UTC date-time value.');
      }
      return parsed;
    }
    throw const FormatException('Expected a date-time value.');
  }

  static DateTime _requireUtc(DateTime value, String label) {
    if (!value.isUtc) {
      throw StateError('$label must be UTC.');
    }
    return value;
  }

  static String _canonicalUuid(String value, String label) {
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(value)) {
      throw FormatException('$label must be a canonical lowercase UUID.');
    }
    return value;
  }
}
