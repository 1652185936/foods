// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MealLogsTable extends MealLogs with TableInfo<$MealLogsTable, MealLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealTypeMeta = const VerificationMeta(
    'mealType',
  );
  @override
  late final GeneratedColumn<String> mealType = GeneratedColumn<String>(
    'meal_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtUtcMsMeta = const VerificationMeta(
    'occurredAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> occurredAtUtcMs = GeneratedColumn<int>(
    'occurred_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneIdMeta = const VerificationMeta(
    'timeZoneId',
  );
  @override
  late final GeneratedColumn<String> timeZoneId = GeneratedColumn<String>(
    'time_zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isWithinEatingWindowMeta =
      const VerificationMeta('isWithinEatingWindow');
  @override
  late final GeneratedColumn<bool> isWithinEatingWindow = GeneratedColumn<bool>(
    'is_within_eating_window',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_within_eating_window" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtUtcMsMeta = const VerificationMeta(
    'createdAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> createdAtUtcMs = GeneratedColumn<int>(
    'created_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMsMeta = const VerificationMeta(
    'updatedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtcMs = GeneratedColumn<int>(
    'updated_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUtcMsMeta = const VerificationMeta(
    'deletedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtcMs = GeneratedColumn<int>(
    'deleted_at_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerUserId,
    id,
    mealType,
    source,
    occurredAtUtcMs,
    timeZoneId,
    localDay,
    isWithinEatingWindow,
    createdAtUtcMs,
    updatedAtUtcMs,
    deletedAtUtcMs,
    serverVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meal_type')) {
      context.handle(
        _mealTypeMeta,
        mealType.isAcceptableOrUnknown(data['meal_type']!, _mealTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mealTypeMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('occurred_at_utc_ms')) {
      context.handle(
        _occurredAtUtcMsMeta,
        occurredAtUtcMs.isAcceptableOrUnknown(
          data['occurred_at_utc_ms']!,
          _occurredAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurredAtUtcMsMeta);
    }
    if (data.containsKey('time_zone_id')) {
      context.handle(
        _timeZoneIdMeta,
        timeZoneId.isAcceptableOrUnknown(
          data['time_zone_id']!,
          _timeZoneIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timeZoneIdMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('is_within_eating_window')) {
      context.handle(
        _isWithinEatingWindowMeta,
        isWithinEatingWindow.isAcceptableOrUnknown(
          data['is_within_eating_window']!,
          _isWithinEatingWindowMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isWithinEatingWindowMeta);
    }
    if (data.containsKey('created_at_utc_ms')) {
      context.handle(
        _createdAtUtcMsMeta,
        createdAtUtcMs.isAcceptableOrUnknown(
          data['created_at_utc_ms']!,
          _createdAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMsMeta);
    }
    if (data.containsKey('updated_at_utc_ms')) {
      context.handle(
        _updatedAtUtcMsMeta,
        updatedAtUtcMs.isAcceptableOrUnknown(
          data['updated_at_utc_ms']!,
          _updatedAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMsMeta);
    }
    if (data.containsKey('deleted_at_utc_ms')) {
      context.handle(
        _deletedAtUtcMsMeta,
        deletedAtUtcMs.isAcceptableOrUnknown(
          data['deleted_at_utc_ms']!,
          _deletedAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerUserId, id};
  @override
  MealLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealLog(
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mealType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_type'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      occurredAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at_utc_ms'],
      )!,
      timeZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone_id'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      isWithinEatingWindow: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_within_eating_window'],
      )!,
      createdAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_ms'],
      )!,
      updatedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc_ms'],
      )!,
      deletedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc_ms'],
      ),
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
    );
  }

  @override
  $MealLogsTable createAlias(String alias) {
    return $MealLogsTable(attachedDatabase, alias);
  }
}

class MealLog extends DataClass implements Insertable<MealLog> {
  final String ownerUserId;
  final String id;
  final String mealType;
  final String source;
  final int occurredAtUtcMs;
  final String timeZoneId;
  final String localDay;
  final bool isWithinEatingWindow;
  final int createdAtUtcMs;
  final int updatedAtUtcMs;
  final int? deletedAtUtcMs;
  final int serverVersion;
  const MealLog({
    required this.ownerUserId,
    required this.id,
    required this.mealType,
    required this.source,
    required this.occurredAtUtcMs,
    required this.timeZoneId,
    required this.localDay,
    required this.isWithinEatingWindow,
    required this.createdAtUtcMs,
    required this.updatedAtUtcMs,
    this.deletedAtUtcMs,
    required this.serverVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['id'] = Variable<String>(id);
    map['meal_type'] = Variable<String>(mealType);
    map['source'] = Variable<String>(source);
    map['occurred_at_utc_ms'] = Variable<int>(occurredAtUtcMs);
    map['time_zone_id'] = Variable<String>(timeZoneId);
    map['local_day'] = Variable<String>(localDay);
    map['is_within_eating_window'] = Variable<bool>(isWithinEatingWindow);
    map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs);
    map['updated_at_utc_ms'] = Variable<int>(updatedAtUtcMs);
    if (!nullToAbsent || deletedAtUtcMs != null) {
      map['deleted_at_utc_ms'] = Variable<int>(deletedAtUtcMs);
    }
    map['server_version'] = Variable<int>(serverVersion);
    return map;
  }

  MealLogsCompanion toCompanion(bool nullToAbsent) {
    return MealLogsCompanion(
      ownerUserId: Value(ownerUserId),
      id: Value(id),
      mealType: Value(mealType),
      source: Value(source),
      occurredAtUtcMs: Value(occurredAtUtcMs),
      timeZoneId: Value(timeZoneId),
      localDay: Value(localDay),
      isWithinEatingWindow: Value(isWithinEatingWindow),
      createdAtUtcMs: Value(createdAtUtcMs),
      updatedAtUtcMs: Value(updatedAtUtcMs),
      deletedAtUtcMs: deletedAtUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtcMs),
      serverVersion: Value(serverVersion),
    );
  }

  factory MealLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealLog(
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      id: serializer.fromJson<String>(json['id']),
      mealType: serializer.fromJson<String>(json['mealType']),
      source: serializer.fromJson<String>(json['source']),
      occurredAtUtcMs: serializer.fromJson<int>(json['occurredAtUtcMs']),
      timeZoneId: serializer.fromJson<String>(json['timeZoneId']),
      localDay: serializer.fromJson<String>(json['localDay']),
      isWithinEatingWindow: serializer.fromJson<bool>(
        json['isWithinEatingWindow'],
      ),
      createdAtUtcMs: serializer.fromJson<int>(json['createdAtUtcMs']),
      updatedAtUtcMs: serializer.fromJson<int>(json['updatedAtUtcMs']),
      deletedAtUtcMs: serializer.fromJson<int?>(json['deletedAtUtcMs']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'id': serializer.toJson<String>(id),
      'mealType': serializer.toJson<String>(mealType),
      'source': serializer.toJson<String>(source),
      'occurredAtUtcMs': serializer.toJson<int>(occurredAtUtcMs),
      'timeZoneId': serializer.toJson<String>(timeZoneId),
      'localDay': serializer.toJson<String>(localDay),
      'isWithinEatingWindow': serializer.toJson<bool>(isWithinEatingWindow),
      'createdAtUtcMs': serializer.toJson<int>(createdAtUtcMs),
      'updatedAtUtcMs': serializer.toJson<int>(updatedAtUtcMs),
      'deletedAtUtcMs': serializer.toJson<int?>(deletedAtUtcMs),
      'serverVersion': serializer.toJson<int>(serverVersion),
    };
  }

  MealLog copyWith({
    String? ownerUserId,
    String? id,
    String? mealType,
    String? source,
    int? occurredAtUtcMs,
    String? timeZoneId,
    String? localDay,
    bool? isWithinEatingWindow,
    int? createdAtUtcMs,
    int? updatedAtUtcMs,
    Value<int?> deletedAtUtcMs = const Value.absent(),
    int? serverVersion,
  }) => MealLog(
    ownerUserId: ownerUserId ?? this.ownerUserId,
    id: id ?? this.id,
    mealType: mealType ?? this.mealType,
    source: source ?? this.source,
    occurredAtUtcMs: occurredAtUtcMs ?? this.occurredAtUtcMs,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    localDay: localDay ?? this.localDay,
    isWithinEatingWindow: isWithinEatingWindow ?? this.isWithinEatingWindow,
    createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
    updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
    deletedAtUtcMs: deletedAtUtcMs.present
        ? deletedAtUtcMs.value
        : this.deletedAtUtcMs,
    serverVersion: serverVersion ?? this.serverVersion,
  );
  MealLog copyWithCompanion(MealLogsCompanion data) {
    return MealLog(
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      id: data.id.present ? data.id.value : this.id,
      mealType: data.mealType.present ? data.mealType.value : this.mealType,
      source: data.source.present ? data.source.value : this.source,
      occurredAtUtcMs: data.occurredAtUtcMs.present
          ? data.occurredAtUtcMs.value
          : this.occurredAtUtcMs,
      timeZoneId: data.timeZoneId.present
          ? data.timeZoneId.value
          : this.timeZoneId,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      isWithinEatingWindow: data.isWithinEatingWindow.present
          ? data.isWithinEatingWindow.value
          : this.isWithinEatingWindow,
      createdAtUtcMs: data.createdAtUtcMs.present
          ? data.createdAtUtcMs.value
          : this.createdAtUtcMs,
      updatedAtUtcMs: data.updatedAtUtcMs.present
          ? data.updatedAtUtcMs.value
          : this.updatedAtUtcMs,
      deletedAtUtcMs: data.deletedAtUtcMs.present
          ? data.deletedAtUtcMs.value
          : this.deletedAtUtcMs,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealLog(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('id: $id, ')
          ..write('mealType: $mealType, ')
          ..write('source: $source, ')
          ..write('occurredAtUtcMs: $occurredAtUtcMs, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('localDay: $localDay, ')
          ..write('isWithinEatingWindow: $isWithinEatingWindow, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('updatedAtUtcMs: $updatedAtUtcMs, ')
          ..write('deletedAtUtcMs: $deletedAtUtcMs, ')
          ..write('serverVersion: $serverVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerUserId,
    id,
    mealType,
    source,
    occurredAtUtcMs,
    timeZoneId,
    localDay,
    isWithinEatingWindow,
    createdAtUtcMs,
    updatedAtUtcMs,
    deletedAtUtcMs,
    serverVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealLog &&
          other.ownerUserId == this.ownerUserId &&
          other.id == this.id &&
          other.mealType == this.mealType &&
          other.source == this.source &&
          other.occurredAtUtcMs == this.occurredAtUtcMs &&
          other.timeZoneId == this.timeZoneId &&
          other.localDay == this.localDay &&
          other.isWithinEatingWindow == this.isWithinEatingWindow &&
          other.createdAtUtcMs == this.createdAtUtcMs &&
          other.updatedAtUtcMs == this.updatedAtUtcMs &&
          other.deletedAtUtcMs == this.deletedAtUtcMs &&
          other.serverVersion == this.serverVersion);
}

class MealLogsCompanion extends UpdateCompanion<MealLog> {
  final Value<String> ownerUserId;
  final Value<String> id;
  final Value<String> mealType;
  final Value<String> source;
  final Value<int> occurredAtUtcMs;
  final Value<String> timeZoneId;
  final Value<String> localDay;
  final Value<bool> isWithinEatingWindow;
  final Value<int> createdAtUtcMs;
  final Value<int> updatedAtUtcMs;
  final Value<int?> deletedAtUtcMs;
  final Value<int> serverVersion;
  final Value<int> rowid;
  const MealLogsCompanion({
    this.ownerUserId = const Value.absent(),
    this.id = const Value.absent(),
    this.mealType = const Value.absent(),
    this.source = const Value.absent(),
    this.occurredAtUtcMs = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.localDay = const Value.absent(),
    this.isWithinEatingWindow = const Value.absent(),
    this.createdAtUtcMs = const Value.absent(),
    this.updatedAtUtcMs = const Value.absent(),
    this.deletedAtUtcMs = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealLogsCompanion.insert({
    required String ownerUserId,
    required String id,
    required String mealType,
    required String source,
    required int occurredAtUtcMs,
    required String timeZoneId,
    required String localDay,
    required bool isWithinEatingWindow,
    required int createdAtUtcMs,
    required int updatedAtUtcMs,
    this.deletedAtUtcMs = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerUserId = Value(ownerUserId),
       id = Value(id),
       mealType = Value(mealType),
       source = Value(source),
       occurredAtUtcMs = Value(occurredAtUtcMs),
       timeZoneId = Value(timeZoneId),
       localDay = Value(localDay),
       isWithinEatingWindow = Value(isWithinEatingWindow),
       createdAtUtcMs = Value(createdAtUtcMs),
       updatedAtUtcMs = Value(updatedAtUtcMs);
  static Insertable<MealLog> custom({
    Expression<String>? ownerUserId,
    Expression<String>? id,
    Expression<String>? mealType,
    Expression<String>? source,
    Expression<int>? occurredAtUtcMs,
    Expression<String>? timeZoneId,
    Expression<String>? localDay,
    Expression<bool>? isWithinEatingWindow,
    Expression<int>? createdAtUtcMs,
    Expression<int>? updatedAtUtcMs,
    Expression<int>? deletedAtUtcMs,
    Expression<int>? serverVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (id != null) 'id': id,
      if (mealType != null) 'meal_type': mealType,
      if (source != null) 'source': source,
      if (occurredAtUtcMs != null) 'occurred_at_utc_ms': occurredAtUtcMs,
      if (timeZoneId != null) 'time_zone_id': timeZoneId,
      if (localDay != null) 'local_day': localDay,
      if (isWithinEatingWindow != null)
        'is_within_eating_window': isWithinEatingWindow,
      if (createdAtUtcMs != null) 'created_at_utc_ms': createdAtUtcMs,
      if (updatedAtUtcMs != null) 'updated_at_utc_ms': updatedAtUtcMs,
      if (deletedAtUtcMs != null) 'deleted_at_utc_ms': deletedAtUtcMs,
      if (serverVersion != null) 'server_version': serverVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealLogsCompanion copyWith({
    Value<String>? ownerUserId,
    Value<String>? id,
    Value<String>? mealType,
    Value<String>? source,
    Value<int>? occurredAtUtcMs,
    Value<String>? timeZoneId,
    Value<String>? localDay,
    Value<bool>? isWithinEatingWindow,
    Value<int>? createdAtUtcMs,
    Value<int>? updatedAtUtcMs,
    Value<int?>? deletedAtUtcMs,
    Value<int>? serverVersion,
    Value<int>? rowid,
  }) {
    return MealLogsCompanion(
      ownerUserId: ownerUserId ?? this.ownerUserId,
      id: id ?? this.id,
      mealType: mealType ?? this.mealType,
      source: source ?? this.source,
      occurredAtUtcMs: occurredAtUtcMs ?? this.occurredAtUtcMs,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      localDay: localDay ?? this.localDay,
      isWithinEatingWindow: isWithinEatingWindow ?? this.isWithinEatingWindow,
      createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
      updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
      deletedAtUtcMs: deletedAtUtcMs ?? this.deletedAtUtcMs,
      serverVersion: serverVersion ?? this.serverVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mealType.present) {
      map['meal_type'] = Variable<String>(mealType.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (occurredAtUtcMs.present) {
      map['occurred_at_utc_ms'] = Variable<int>(occurredAtUtcMs.value);
    }
    if (timeZoneId.present) {
      map['time_zone_id'] = Variable<String>(timeZoneId.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (isWithinEatingWindow.present) {
      map['is_within_eating_window'] = Variable<bool>(
        isWithinEatingWindow.value,
      );
    }
    if (createdAtUtcMs.present) {
      map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs.value);
    }
    if (updatedAtUtcMs.present) {
      map['updated_at_utc_ms'] = Variable<int>(updatedAtUtcMs.value);
    }
    if (deletedAtUtcMs.present) {
      map['deleted_at_utc_ms'] = Variable<int>(deletedAtUtcMs.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealLogsCompanion(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('id: $id, ')
          ..write('mealType: $mealType, ')
          ..write('source: $source, ')
          ..write('occurredAtUtcMs: $occurredAtUtcMs, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('localDay: $localDay, ')
          ..write('isWithinEatingWindow: $isWithinEatingWindow, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('updatedAtUtcMs: $updatedAtUtcMs, ')
          ..write('deletedAtUtcMs: $deletedAtUtcMs, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealItemsTable extends MealItems
    with TableInfo<$MealItemsTable, MealItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealLogIdMeta = const VerificationMeta(
    'mealLogId',
  );
  @override
  late final GeneratedColumn<String> mealLogId = GeneratedColumn<String>(
    'meal_log_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _servingMilliMeta = const VerificationMeta(
    'servingMilli',
  );
  @override
  late final GeneratedColumn<int> servingMilli = GeneratedColumn<int>(
    'serving_milli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _energyKcalMeta = const VerificationMeta(
    'energyKcal',
  );
  @override
  late final GeneratedColumn<int> energyKcal = GeneratedColumn<int>(
    'energy_kcal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinMgMeta = const VerificationMeta(
    'proteinMg',
  );
  @override
  late final GeneratedColumn<int> proteinMg = GeneratedColumn<int>(
    'protein_mg',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbsMgMeta = const VerificationMeta(
    'carbsMg',
  );
  @override
  late final GeneratedColumn<int> carbsMg = GeneratedColumn<int>(
    'carbs_mg',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatMgMeta = const VerificationMeta('fatMg');
  @override
  late final GeneratedColumn<int> fatMg = GeneratedColumn<int>(
    'fat_mg',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageReferenceMeta = const VerificationMeta(
    'imageReference',
  );
  @override
  late final GeneratedColumn<String> imageReference = GeneratedColumn<String>(
    'image_reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMsMeta = const VerificationMeta(
    'createdAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> createdAtUtcMs = GeneratedColumn<int>(
    'created_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMsMeta = const VerificationMeta(
    'updatedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtcMs = GeneratedColumn<int>(
    'updated_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerUserId,
    id,
    mealLogId,
    name,
    servingMilli,
    energyKcal,
    proteinMg,
    carbsMg,
    fatMg,
    imageReference,
    createdAtUtcMs,
    updatedAtUtcMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meal_log_id')) {
      context.handle(
        _mealLogIdMeta,
        mealLogId.isAcceptableOrUnknown(data['meal_log_id']!, _mealLogIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mealLogIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('serving_milli')) {
      context.handle(
        _servingMilliMeta,
        servingMilli.isAcceptableOrUnknown(
          data['serving_milli']!,
          _servingMilliMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_servingMilliMeta);
    }
    if (data.containsKey('energy_kcal')) {
      context.handle(
        _energyKcalMeta,
        energyKcal.isAcceptableOrUnknown(data['energy_kcal']!, _energyKcalMeta),
      );
    } else if (isInserting) {
      context.missing(_energyKcalMeta);
    }
    if (data.containsKey('protein_mg')) {
      context.handle(
        _proteinMgMeta,
        proteinMg.isAcceptableOrUnknown(data['protein_mg']!, _proteinMgMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinMgMeta);
    }
    if (data.containsKey('carbs_mg')) {
      context.handle(
        _carbsMgMeta,
        carbsMg.isAcceptableOrUnknown(data['carbs_mg']!, _carbsMgMeta),
      );
    } else if (isInserting) {
      context.missing(_carbsMgMeta);
    }
    if (data.containsKey('fat_mg')) {
      context.handle(
        _fatMgMeta,
        fatMg.isAcceptableOrUnknown(data['fat_mg']!, _fatMgMeta),
      );
    } else if (isInserting) {
      context.missing(_fatMgMeta);
    }
    if (data.containsKey('image_reference')) {
      context.handle(
        _imageReferenceMeta,
        imageReference.isAcceptableOrUnknown(
          data['image_reference']!,
          _imageReferenceMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc_ms')) {
      context.handle(
        _createdAtUtcMsMeta,
        createdAtUtcMs.isAcceptableOrUnknown(
          data['created_at_utc_ms']!,
          _createdAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMsMeta);
    }
    if (data.containsKey('updated_at_utc_ms')) {
      context.handle(
        _updatedAtUtcMsMeta,
        updatedAtUtcMs.isAcceptableOrUnknown(
          data['updated_at_utc_ms']!,
          _updatedAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerUserId, id};
  @override
  MealItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealItem(
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mealLogId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_log_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      servingMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}serving_milli'],
      )!,
      energyKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy_kcal'],
      )!,
      proteinMg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protein_mg'],
      )!,
      carbsMg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carbs_mg'],
      )!,
      fatMg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fat_mg'],
      )!,
      imageReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_reference'],
      ),
      createdAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_ms'],
      )!,
      updatedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc_ms'],
      )!,
    );
  }

  @override
  $MealItemsTable createAlias(String alias) {
    return $MealItemsTable(attachedDatabase, alias);
  }
}

class MealItem extends DataClass implements Insertable<MealItem> {
  final String ownerUserId;
  final String id;
  final String mealLogId;
  final String name;
  final int servingMilli;
  final int energyKcal;
  final int proteinMg;
  final int carbsMg;
  final int fatMg;
  final String? imageReference;
  final int createdAtUtcMs;
  final int updatedAtUtcMs;
  const MealItem({
    required this.ownerUserId,
    required this.id,
    required this.mealLogId,
    required this.name,
    required this.servingMilli,
    required this.energyKcal,
    required this.proteinMg,
    required this.carbsMg,
    required this.fatMg,
    this.imageReference,
    required this.createdAtUtcMs,
    required this.updatedAtUtcMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['id'] = Variable<String>(id);
    map['meal_log_id'] = Variable<String>(mealLogId);
    map['name'] = Variable<String>(name);
    map['serving_milli'] = Variable<int>(servingMilli);
    map['energy_kcal'] = Variable<int>(energyKcal);
    map['protein_mg'] = Variable<int>(proteinMg);
    map['carbs_mg'] = Variable<int>(carbsMg);
    map['fat_mg'] = Variable<int>(fatMg);
    if (!nullToAbsent || imageReference != null) {
      map['image_reference'] = Variable<String>(imageReference);
    }
    map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs);
    map['updated_at_utc_ms'] = Variable<int>(updatedAtUtcMs);
    return map;
  }

  MealItemsCompanion toCompanion(bool nullToAbsent) {
    return MealItemsCompanion(
      ownerUserId: Value(ownerUserId),
      id: Value(id),
      mealLogId: Value(mealLogId),
      name: Value(name),
      servingMilli: Value(servingMilli),
      energyKcal: Value(energyKcal),
      proteinMg: Value(proteinMg),
      carbsMg: Value(carbsMg),
      fatMg: Value(fatMg),
      imageReference: imageReference == null && nullToAbsent
          ? const Value.absent()
          : Value(imageReference),
      createdAtUtcMs: Value(createdAtUtcMs),
      updatedAtUtcMs: Value(updatedAtUtcMs),
    );
  }

  factory MealItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealItem(
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      id: serializer.fromJson<String>(json['id']),
      mealLogId: serializer.fromJson<String>(json['mealLogId']),
      name: serializer.fromJson<String>(json['name']),
      servingMilli: serializer.fromJson<int>(json['servingMilli']),
      energyKcal: serializer.fromJson<int>(json['energyKcal']),
      proteinMg: serializer.fromJson<int>(json['proteinMg']),
      carbsMg: serializer.fromJson<int>(json['carbsMg']),
      fatMg: serializer.fromJson<int>(json['fatMg']),
      imageReference: serializer.fromJson<String?>(json['imageReference']),
      createdAtUtcMs: serializer.fromJson<int>(json['createdAtUtcMs']),
      updatedAtUtcMs: serializer.fromJson<int>(json['updatedAtUtcMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'id': serializer.toJson<String>(id),
      'mealLogId': serializer.toJson<String>(mealLogId),
      'name': serializer.toJson<String>(name),
      'servingMilli': serializer.toJson<int>(servingMilli),
      'energyKcal': serializer.toJson<int>(energyKcal),
      'proteinMg': serializer.toJson<int>(proteinMg),
      'carbsMg': serializer.toJson<int>(carbsMg),
      'fatMg': serializer.toJson<int>(fatMg),
      'imageReference': serializer.toJson<String?>(imageReference),
      'createdAtUtcMs': serializer.toJson<int>(createdAtUtcMs),
      'updatedAtUtcMs': serializer.toJson<int>(updatedAtUtcMs),
    };
  }

  MealItem copyWith({
    String? ownerUserId,
    String? id,
    String? mealLogId,
    String? name,
    int? servingMilli,
    int? energyKcal,
    int? proteinMg,
    int? carbsMg,
    int? fatMg,
    Value<String?> imageReference = const Value.absent(),
    int? createdAtUtcMs,
    int? updatedAtUtcMs,
  }) => MealItem(
    ownerUserId: ownerUserId ?? this.ownerUserId,
    id: id ?? this.id,
    mealLogId: mealLogId ?? this.mealLogId,
    name: name ?? this.name,
    servingMilli: servingMilli ?? this.servingMilli,
    energyKcal: energyKcal ?? this.energyKcal,
    proteinMg: proteinMg ?? this.proteinMg,
    carbsMg: carbsMg ?? this.carbsMg,
    fatMg: fatMg ?? this.fatMg,
    imageReference: imageReference.present
        ? imageReference.value
        : this.imageReference,
    createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
    updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
  );
  MealItem copyWithCompanion(MealItemsCompanion data) {
    return MealItem(
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      id: data.id.present ? data.id.value : this.id,
      mealLogId: data.mealLogId.present ? data.mealLogId.value : this.mealLogId,
      name: data.name.present ? data.name.value : this.name,
      servingMilli: data.servingMilli.present
          ? data.servingMilli.value
          : this.servingMilli,
      energyKcal: data.energyKcal.present
          ? data.energyKcal.value
          : this.energyKcal,
      proteinMg: data.proteinMg.present ? data.proteinMg.value : this.proteinMg,
      carbsMg: data.carbsMg.present ? data.carbsMg.value : this.carbsMg,
      fatMg: data.fatMg.present ? data.fatMg.value : this.fatMg,
      imageReference: data.imageReference.present
          ? data.imageReference.value
          : this.imageReference,
      createdAtUtcMs: data.createdAtUtcMs.present
          ? data.createdAtUtcMs.value
          : this.createdAtUtcMs,
      updatedAtUtcMs: data.updatedAtUtcMs.present
          ? data.updatedAtUtcMs.value
          : this.updatedAtUtcMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealItem(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('id: $id, ')
          ..write('mealLogId: $mealLogId, ')
          ..write('name: $name, ')
          ..write('servingMilli: $servingMilli, ')
          ..write('energyKcal: $energyKcal, ')
          ..write('proteinMg: $proteinMg, ')
          ..write('carbsMg: $carbsMg, ')
          ..write('fatMg: $fatMg, ')
          ..write('imageReference: $imageReference, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('updatedAtUtcMs: $updatedAtUtcMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerUserId,
    id,
    mealLogId,
    name,
    servingMilli,
    energyKcal,
    proteinMg,
    carbsMg,
    fatMg,
    imageReference,
    createdAtUtcMs,
    updatedAtUtcMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealItem &&
          other.ownerUserId == this.ownerUserId &&
          other.id == this.id &&
          other.mealLogId == this.mealLogId &&
          other.name == this.name &&
          other.servingMilli == this.servingMilli &&
          other.energyKcal == this.energyKcal &&
          other.proteinMg == this.proteinMg &&
          other.carbsMg == this.carbsMg &&
          other.fatMg == this.fatMg &&
          other.imageReference == this.imageReference &&
          other.createdAtUtcMs == this.createdAtUtcMs &&
          other.updatedAtUtcMs == this.updatedAtUtcMs);
}

class MealItemsCompanion extends UpdateCompanion<MealItem> {
  final Value<String> ownerUserId;
  final Value<String> id;
  final Value<String> mealLogId;
  final Value<String> name;
  final Value<int> servingMilli;
  final Value<int> energyKcal;
  final Value<int> proteinMg;
  final Value<int> carbsMg;
  final Value<int> fatMg;
  final Value<String?> imageReference;
  final Value<int> createdAtUtcMs;
  final Value<int> updatedAtUtcMs;
  final Value<int> rowid;
  const MealItemsCompanion({
    this.ownerUserId = const Value.absent(),
    this.id = const Value.absent(),
    this.mealLogId = const Value.absent(),
    this.name = const Value.absent(),
    this.servingMilli = const Value.absent(),
    this.energyKcal = const Value.absent(),
    this.proteinMg = const Value.absent(),
    this.carbsMg = const Value.absent(),
    this.fatMg = const Value.absent(),
    this.imageReference = const Value.absent(),
    this.createdAtUtcMs = const Value.absent(),
    this.updatedAtUtcMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealItemsCompanion.insert({
    required String ownerUserId,
    required String id,
    required String mealLogId,
    required String name,
    required int servingMilli,
    required int energyKcal,
    required int proteinMg,
    required int carbsMg,
    required int fatMg,
    this.imageReference = const Value.absent(),
    required int createdAtUtcMs,
    required int updatedAtUtcMs,
    this.rowid = const Value.absent(),
  }) : ownerUserId = Value(ownerUserId),
       id = Value(id),
       mealLogId = Value(mealLogId),
       name = Value(name),
       servingMilli = Value(servingMilli),
       energyKcal = Value(energyKcal),
       proteinMg = Value(proteinMg),
       carbsMg = Value(carbsMg),
       fatMg = Value(fatMg),
       createdAtUtcMs = Value(createdAtUtcMs),
       updatedAtUtcMs = Value(updatedAtUtcMs);
  static Insertable<MealItem> custom({
    Expression<String>? ownerUserId,
    Expression<String>? id,
    Expression<String>? mealLogId,
    Expression<String>? name,
    Expression<int>? servingMilli,
    Expression<int>? energyKcal,
    Expression<int>? proteinMg,
    Expression<int>? carbsMg,
    Expression<int>? fatMg,
    Expression<String>? imageReference,
    Expression<int>? createdAtUtcMs,
    Expression<int>? updatedAtUtcMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (id != null) 'id': id,
      if (mealLogId != null) 'meal_log_id': mealLogId,
      if (name != null) 'name': name,
      if (servingMilli != null) 'serving_milli': servingMilli,
      if (energyKcal != null) 'energy_kcal': energyKcal,
      if (proteinMg != null) 'protein_mg': proteinMg,
      if (carbsMg != null) 'carbs_mg': carbsMg,
      if (fatMg != null) 'fat_mg': fatMg,
      if (imageReference != null) 'image_reference': imageReference,
      if (createdAtUtcMs != null) 'created_at_utc_ms': createdAtUtcMs,
      if (updatedAtUtcMs != null) 'updated_at_utc_ms': updatedAtUtcMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealItemsCompanion copyWith({
    Value<String>? ownerUserId,
    Value<String>? id,
    Value<String>? mealLogId,
    Value<String>? name,
    Value<int>? servingMilli,
    Value<int>? energyKcal,
    Value<int>? proteinMg,
    Value<int>? carbsMg,
    Value<int>? fatMg,
    Value<String?>? imageReference,
    Value<int>? createdAtUtcMs,
    Value<int>? updatedAtUtcMs,
    Value<int>? rowid,
  }) {
    return MealItemsCompanion(
      ownerUserId: ownerUserId ?? this.ownerUserId,
      id: id ?? this.id,
      mealLogId: mealLogId ?? this.mealLogId,
      name: name ?? this.name,
      servingMilli: servingMilli ?? this.servingMilli,
      energyKcal: energyKcal ?? this.energyKcal,
      proteinMg: proteinMg ?? this.proteinMg,
      carbsMg: carbsMg ?? this.carbsMg,
      fatMg: fatMg ?? this.fatMg,
      imageReference: imageReference ?? this.imageReference,
      createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
      updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mealLogId.present) {
      map['meal_log_id'] = Variable<String>(mealLogId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (servingMilli.present) {
      map['serving_milli'] = Variable<int>(servingMilli.value);
    }
    if (energyKcal.present) {
      map['energy_kcal'] = Variable<int>(energyKcal.value);
    }
    if (proteinMg.present) {
      map['protein_mg'] = Variable<int>(proteinMg.value);
    }
    if (carbsMg.present) {
      map['carbs_mg'] = Variable<int>(carbsMg.value);
    }
    if (fatMg.present) {
      map['fat_mg'] = Variable<int>(fatMg.value);
    }
    if (imageReference.present) {
      map['image_reference'] = Variable<String>(imageReference.value);
    }
    if (createdAtUtcMs.present) {
      map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs.value);
    }
    if (updatedAtUtcMs.present) {
      map['updated_at_utc_ms'] = Variable<int>(updatedAtUtcMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealItemsCompanion(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('id: $id, ')
          ..write('mealLogId: $mealLogId, ')
          ..write('name: $name, ')
          ..write('servingMilli: $servingMilli, ')
          ..write('energyKcal: $energyKcal, ')
          ..write('proteinMg: $proteinMg, ')
          ..write('carbsMg: $carbsMg, ')
          ..write('fatMg: $fatMg, ')
          ..write('imageReference: $imageReference, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('updatedAtUtcMs: $updatedAtUtcMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FastingSessionsTable extends FastingSessions
    with TableInfo<$FastingSessionsTable, FastingSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FastingSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planMeta = const VerificationMeta('plan');
  @override
  late final GeneratedColumn<String> plan = GeneratedColumn<String>(
    'plan',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeSlotMeta = const VerificationMeta(
    'activeSlot',
  );
  @override
  late final GeneratedColumn<int> activeSlot = GeneratedColumn<int>(
    'active_slot',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtUtcMsMeta = const VerificationMeta(
    'startedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> startedAtUtcMs = GeneratedColumn<int>(
    'started_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetEndAtUtcMsMeta = const VerificationMeta(
    'targetEndAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> targetEndAtUtcMs = GeneratedColumn<int>(
    'target_end_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtUtcMsMeta = const VerificationMeta(
    'endedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> endedAtUtcMs = GeneratedColumn<int>(
    'ended_at_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeZoneIdMeta = const VerificationMeta(
    'timeZoneId',
  );
  @override
  late final GeneratedColumn<String> timeZoneId = GeneratedColumn<String>(
    'time_zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedLocalDayMeta = const VerificationMeta(
    'startedLocalDay',
  );
  @override
  late final GeneratedColumn<String> startedLocalDay = GeneratedColumn<String>(
    'started_local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetEndLocalDayMeta = const VerificationMeta(
    'targetEndLocalDay',
  );
  @override
  late final GeneratedColumn<String> targetEndLocalDay =
      GeneratedColumn<String>(
        'target_end_local_day',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _endedLocalDayMeta = const VerificationMeta(
    'endedLocalDay',
  );
  @override
  late final GeneratedColumn<String> endedLocalDay = GeneratedColumn<String>(
    'ended_local_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMsMeta = const VerificationMeta(
    'createdAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> createdAtUtcMs = GeneratedColumn<int>(
    'created_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMsMeta = const VerificationMeta(
    'updatedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtcMs = GeneratedColumn<int>(
    'updated_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerUserId,
    id,
    plan,
    status,
    activeSlot,
    startedAtUtcMs,
    targetEndAtUtcMs,
    endedAtUtcMs,
    timeZoneId,
    startedLocalDay,
    targetEndLocalDay,
    endedLocalDay,
    createdAtUtcMs,
    updatedAtUtcMs,
    serverVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fasting_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FastingSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan')) {
      context.handle(
        _planMeta,
        plan.isAcceptableOrUnknown(data['plan']!, _planMeta),
      );
    } else if (isInserting) {
      context.missing(_planMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('active_slot')) {
      context.handle(
        _activeSlotMeta,
        activeSlot.isAcceptableOrUnknown(data['active_slot']!, _activeSlotMeta),
      );
    }
    if (data.containsKey('started_at_utc_ms')) {
      context.handle(
        _startedAtUtcMsMeta,
        startedAtUtcMs.isAcceptableOrUnknown(
          data['started_at_utc_ms']!,
          _startedAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUtcMsMeta);
    }
    if (data.containsKey('target_end_at_utc_ms')) {
      context.handle(
        _targetEndAtUtcMsMeta,
        targetEndAtUtcMs.isAcceptableOrUnknown(
          data['target_end_at_utc_ms']!,
          _targetEndAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetEndAtUtcMsMeta);
    }
    if (data.containsKey('ended_at_utc_ms')) {
      context.handle(
        _endedAtUtcMsMeta,
        endedAtUtcMs.isAcceptableOrUnknown(
          data['ended_at_utc_ms']!,
          _endedAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('time_zone_id')) {
      context.handle(
        _timeZoneIdMeta,
        timeZoneId.isAcceptableOrUnknown(
          data['time_zone_id']!,
          _timeZoneIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timeZoneIdMeta);
    }
    if (data.containsKey('started_local_day')) {
      context.handle(
        _startedLocalDayMeta,
        startedLocalDay.isAcceptableOrUnknown(
          data['started_local_day']!,
          _startedLocalDayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedLocalDayMeta);
    }
    if (data.containsKey('target_end_local_day')) {
      context.handle(
        _targetEndLocalDayMeta,
        targetEndLocalDay.isAcceptableOrUnknown(
          data['target_end_local_day']!,
          _targetEndLocalDayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetEndLocalDayMeta);
    }
    if (data.containsKey('ended_local_day')) {
      context.handle(
        _endedLocalDayMeta,
        endedLocalDay.isAcceptableOrUnknown(
          data['ended_local_day']!,
          _endedLocalDayMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc_ms')) {
      context.handle(
        _createdAtUtcMsMeta,
        createdAtUtcMs.isAcceptableOrUnknown(
          data['created_at_utc_ms']!,
          _createdAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMsMeta);
    }
    if (data.containsKey('updated_at_utc_ms')) {
      context.handle(
        _updatedAtUtcMsMeta,
        updatedAtUtcMs.isAcceptableOrUnknown(
          data['updated_at_utc_ms']!,
          _updatedAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMsMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerUserId, id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {ownerUserId, activeSlot},
  ];
  @override
  FastingSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FastingSession(
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      plan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      activeSlot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_slot'],
      ),
      startedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_utc_ms'],
      )!,
      targetEndAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_end_at_utc_ms'],
      )!,
      endedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_utc_ms'],
      ),
      timeZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone_id'],
      )!,
      startedLocalDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_local_day'],
      )!,
      targetEndLocalDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_end_local_day'],
      )!,
      endedLocalDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ended_local_day'],
      ),
      createdAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_ms'],
      )!,
      updatedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc_ms'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
    );
  }

  @override
  $FastingSessionsTable createAlias(String alias) {
    return $FastingSessionsTable(attachedDatabase, alias);
  }
}

class FastingSession extends DataClass implements Insertable<FastingSession> {
  final String ownerUserId;
  final String id;
  final String plan;
  final String status;
  final int? activeSlot;
  final int startedAtUtcMs;
  final int targetEndAtUtcMs;
  final int? endedAtUtcMs;
  final String timeZoneId;
  final String startedLocalDay;
  final String targetEndLocalDay;
  final String? endedLocalDay;
  final int createdAtUtcMs;
  final int updatedAtUtcMs;
  final int serverVersion;
  const FastingSession({
    required this.ownerUserId,
    required this.id,
    required this.plan,
    required this.status,
    this.activeSlot,
    required this.startedAtUtcMs,
    required this.targetEndAtUtcMs,
    this.endedAtUtcMs,
    required this.timeZoneId,
    required this.startedLocalDay,
    required this.targetEndLocalDay,
    this.endedLocalDay,
    required this.createdAtUtcMs,
    required this.updatedAtUtcMs,
    required this.serverVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['id'] = Variable<String>(id);
    map['plan'] = Variable<String>(plan);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || activeSlot != null) {
      map['active_slot'] = Variable<int>(activeSlot);
    }
    map['started_at_utc_ms'] = Variable<int>(startedAtUtcMs);
    map['target_end_at_utc_ms'] = Variable<int>(targetEndAtUtcMs);
    if (!nullToAbsent || endedAtUtcMs != null) {
      map['ended_at_utc_ms'] = Variable<int>(endedAtUtcMs);
    }
    map['time_zone_id'] = Variable<String>(timeZoneId);
    map['started_local_day'] = Variable<String>(startedLocalDay);
    map['target_end_local_day'] = Variable<String>(targetEndLocalDay);
    if (!nullToAbsent || endedLocalDay != null) {
      map['ended_local_day'] = Variable<String>(endedLocalDay);
    }
    map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs);
    map['updated_at_utc_ms'] = Variable<int>(updatedAtUtcMs);
    map['server_version'] = Variable<int>(serverVersion);
    return map;
  }

  FastingSessionsCompanion toCompanion(bool nullToAbsent) {
    return FastingSessionsCompanion(
      ownerUserId: Value(ownerUserId),
      id: Value(id),
      plan: Value(plan),
      status: Value(status),
      activeSlot: activeSlot == null && nullToAbsent
          ? const Value.absent()
          : Value(activeSlot),
      startedAtUtcMs: Value(startedAtUtcMs),
      targetEndAtUtcMs: Value(targetEndAtUtcMs),
      endedAtUtcMs: endedAtUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtUtcMs),
      timeZoneId: Value(timeZoneId),
      startedLocalDay: Value(startedLocalDay),
      targetEndLocalDay: Value(targetEndLocalDay),
      endedLocalDay: endedLocalDay == null && nullToAbsent
          ? const Value.absent()
          : Value(endedLocalDay),
      createdAtUtcMs: Value(createdAtUtcMs),
      updatedAtUtcMs: Value(updatedAtUtcMs),
      serverVersion: Value(serverVersion),
    );
  }

  factory FastingSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FastingSession(
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      id: serializer.fromJson<String>(json['id']),
      plan: serializer.fromJson<String>(json['plan']),
      status: serializer.fromJson<String>(json['status']),
      activeSlot: serializer.fromJson<int?>(json['activeSlot']),
      startedAtUtcMs: serializer.fromJson<int>(json['startedAtUtcMs']),
      targetEndAtUtcMs: serializer.fromJson<int>(json['targetEndAtUtcMs']),
      endedAtUtcMs: serializer.fromJson<int?>(json['endedAtUtcMs']),
      timeZoneId: serializer.fromJson<String>(json['timeZoneId']),
      startedLocalDay: serializer.fromJson<String>(json['startedLocalDay']),
      targetEndLocalDay: serializer.fromJson<String>(json['targetEndLocalDay']),
      endedLocalDay: serializer.fromJson<String?>(json['endedLocalDay']),
      createdAtUtcMs: serializer.fromJson<int>(json['createdAtUtcMs']),
      updatedAtUtcMs: serializer.fromJson<int>(json['updatedAtUtcMs']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'id': serializer.toJson<String>(id),
      'plan': serializer.toJson<String>(plan),
      'status': serializer.toJson<String>(status),
      'activeSlot': serializer.toJson<int?>(activeSlot),
      'startedAtUtcMs': serializer.toJson<int>(startedAtUtcMs),
      'targetEndAtUtcMs': serializer.toJson<int>(targetEndAtUtcMs),
      'endedAtUtcMs': serializer.toJson<int?>(endedAtUtcMs),
      'timeZoneId': serializer.toJson<String>(timeZoneId),
      'startedLocalDay': serializer.toJson<String>(startedLocalDay),
      'targetEndLocalDay': serializer.toJson<String>(targetEndLocalDay),
      'endedLocalDay': serializer.toJson<String?>(endedLocalDay),
      'createdAtUtcMs': serializer.toJson<int>(createdAtUtcMs),
      'updatedAtUtcMs': serializer.toJson<int>(updatedAtUtcMs),
      'serverVersion': serializer.toJson<int>(serverVersion),
    };
  }

  FastingSession copyWith({
    String? ownerUserId,
    String? id,
    String? plan,
    String? status,
    Value<int?> activeSlot = const Value.absent(),
    int? startedAtUtcMs,
    int? targetEndAtUtcMs,
    Value<int?> endedAtUtcMs = const Value.absent(),
    String? timeZoneId,
    String? startedLocalDay,
    String? targetEndLocalDay,
    Value<String?> endedLocalDay = const Value.absent(),
    int? createdAtUtcMs,
    int? updatedAtUtcMs,
    int? serverVersion,
  }) => FastingSession(
    ownerUserId: ownerUserId ?? this.ownerUserId,
    id: id ?? this.id,
    plan: plan ?? this.plan,
    status: status ?? this.status,
    activeSlot: activeSlot.present ? activeSlot.value : this.activeSlot,
    startedAtUtcMs: startedAtUtcMs ?? this.startedAtUtcMs,
    targetEndAtUtcMs: targetEndAtUtcMs ?? this.targetEndAtUtcMs,
    endedAtUtcMs: endedAtUtcMs.present ? endedAtUtcMs.value : this.endedAtUtcMs,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    startedLocalDay: startedLocalDay ?? this.startedLocalDay,
    targetEndLocalDay: targetEndLocalDay ?? this.targetEndLocalDay,
    endedLocalDay: endedLocalDay.present
        ? endedLocalDay.value
        : this.endedLocalDay,
    createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
    updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
    serverVersion: serverVersion ?? this.serverVersion,
  );
  FastingSession copyWithCompanion(FastingSessionsCompanion data) {
    return FastingSession(
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      id: data.id.present ? data.id.value : this.id,
      plan: data.plan.present ? data.plan.value : this.plan,
      status: data.status.present ? data.status.value : this.status,
      activeSlot: data.activeSlot.present
          ? data.activeSlot.value
          : this.activeSlot,
      startedAtUtcMs: data.startedAtUtcMs.present
          ? data.startedAtUtcMs.value
          : this.startedAtUtcMs,
      targetEndAtUtcMs: data.targetEndAtUtcMs.present
          ? data.targetEndAtUtcMs.value
          : this.targetEndAtUtcMs,
      endedAtUtcMs: data.endedAtUtcMs.present
          ? data.endedAtUtcMs.value
          : this.endedAtUtcMs,
      timeZoneId: data.timeZoneId.present
          ? data.timeZoneId.value
          : this.timeZoneId,
      startedLocalDay: data.startedLocalDay.present
          ? data.startedLocalDay.value
          : this.startedLocalDay,
      targetEndLocalDay: data.targetEndLocalDay.present
          ? data.targetEndLocalDay.value
          : this.targetEndLocalDay,
      endedLocalDay: data.endedLocalDay.present
          ? data.endedLocalDay.value
          : this.endedLocalDay,
      createdAtUtcMs: data.createdAtUtcMs.present
          ? data.createdAtUtcMs.value
          : this.createdAtUtcMs,
      updatedAtUtcMs: data.updatedAtUtcMs.present
          ? data.updatedAtUtcMs.value
          : this.updatedAtUtcMs,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FastingSession(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('id: $id, ')
          ..write('plan: $plan, ')
          ..write('status: $status, ')
          ..write('activeSlot: $activeSlot, ')
          ..write('startedAtUtcMs: $startedAtUtcMs, ')
          ..write('targetEndAtUtcMs: $targetEndAtUtcMs, ')
          ..write('endedAtUtcMs: $endedAtUtcMs, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('startedLocalDay: $startedLocalDay, ')
          ..write('targetEndLocalDay: $targetEndLocalDay, ')
          ..write('endedLocalDay: $endedLocalDay, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('updatedAtUtcMs: $updatedAtUtcMs, ')
          ..write('serverVersion: $serverVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerUserId,
    id,
    plan,
    status,
    activeSlot,
    startedAtUtcMs,
    targetEndAtUtcMs,
    endedAtUtcMs,
    timeZoneId,
    startedLocalDay,
    targetEndLocalDay,
    endedLocalDay,
    createdAtUtcMs,
    updatedAtUtcMs,
    serverVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FastingSession &&
          other.ownerUserId == this.ownerUserId &&
          other.id == this.id &&
          other.plan == this.plan &&
          other.status == this.status &&
          other.activeSlot == this.activeSlot &&
          other.startedAtUtcMs == this.startedAtUtcMs &&
          other.targetEndAtUtcMs == this.targetEndAtUtcMs &&
          other.endedAtUtcMs == this.endedAtUtcMs &&
          other.timeZoneId == this.timeZoneId &&
          other.startedLocalDay == this.startedLocalDay &&
          other.targetEndLocalDay == this.targetEndLocalDay &&
          other.endedLocalDay == this.endedLocalDay &&
          other.createdAtUtcMs == this.createdAtUtcMs &&
          other.updatedAtUtcMs == this.updatedAtUtcMs &&
          other.serverVersion == this.serverVersion);
}

class FastingSessionsCompanion extends UpdateCompanion<FastingSession> {
  final Value<String> ownerUserId;
  final Value<String> id;
  final Value<String> plan;
  final Value<String> status;
  final Value<int?> activeSlot;
  final Value<int> startedAtUtcMs;
  final Value<int> targetEndAtUtcMs;
  final Value<int?> endedAtUtcMs;
  final Value<String> timeZoneId;
  final Value<String> startedLocalDay;
  final Value<String> targetEndLocalDay;
  final Value<String?> endedLocalDay;
  final Value<int> createdAtUtcMs;
  final Value<int> updatedAtUtcMs;
  final Value<int> serverVersion;
  final Value<int> rowid;
  const FastingSessionsCompanion({
    this.ownerUserId = const Value.absent(),
    this.id = const Value.absent(),
    this.plan = const Value.absent(),
    this.status = const Value.absent(),
    this.activeSlot = const Value.absent(),
    this.startedAtUtcMs = const Value.absent(),
    this.targetEndAtUtcMs = const Value.absent(),
    this.endedAtUtcMs = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.startedLocalDay = const Value.absent(),
    this.targetEndLocalDay = const Value.absent(),
    this.endedLocalDay = const Value.absent(),
    this.createdAtUtcMs = const Value.absent(),
    this.updatedAtUtcMs = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FastingSessionsCompanion.insert({
    required String ownerUserId,
    required String id,
    required String plan,
    required String status,
    this.activeSlot = const Value.absent(),
    required int startedAtUtcMs,
    required int targetEndAtUtcMs,
    this.endedAtUtcMs = const Value.absent(),
    required String timeZoneId,
    required String startedLocalDay,
    required String targetEndLocalDay,
    this.endedLocalDay = const Value.absent(),
    required int createdAtUtcMs,
    required int updatedAtUtcMs,
    this.serverVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerUserId = Value(ownerUserId),
       id = Value(id),
       plan = Value(plan),
       status = Value(status),
       startedAtUtcMs = Value(startedAtUtcMs),
       targetEndAtUtcMs = Value(targetEndAtUtcMs),
       timeZoneId = Value(timeZoneId),
       startedLocalDay = Value(startedLocalDay),
       targetEndLocalDay = Value(targetEndLocalDay),
       createdAtUtcMs = Value(createdAtUtcMs),
       updatedAtUtcMs = Value(updatedAtUtcMs);
  static Insertable<FastingSession> custom({
    Expression<String>? ownerUserId,
    Expression<String>? id,
    Expression<String>? plan,
    Expression<String>? status,
    Expression<int>? activeSlot,
    Expression<int>? startedAtUtcMs,
    Expression<int>? targetEndAtUtcMs,
    Expression<int>? endedAtUtcMs,
    Expression<String>? timeZoneId,
    Expression<String>? startedLocalDay,
    Expression<String>? targetEndLocalDay,
    Expression<String>? endedLocalDay,
    Expression<int>? createdAtUtcMs,
    Expression<int>? updatedAtUtcMs,
    Expression<int>? serverVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (id != null) 'id': id,
      if (plan != null) 'plan': plan,
      if (status != null) 'status': status,
      if (activeSlot != null) 'active_slot': activeSlot,
      if (startedAtUtcMs != null) 'started_at_utc_ms': startedAtUtcMs,
      if (targetEndAtUtcMs != null) 'target_end_at_utc_ms': targetEndAtUtcMs,
      if (endedAtUtcMs != null) 'ended_at_utc_ms': endedAtUtcMs,
      if (timeZoneId != null) 'time_zone_id': timeZoneId,
      if (startedLocalDay != null) 'started_local_day': startedLocalDay,
      if (targetEndLocalDay != null) 'target_end_local_day': targetEndLocalDay,
      if (endedLocalDay != null) 'ended_local_day': endedLocalDay,
      if (createdAtUtcMs != null) 'created_at_utc_ms': createdAtUtcMs,
      if (updatedAtUtcMs != null) 'updated_at_utc_ms': updatedAtUtcMs,
      if (serverVersion != null) 'server_version': serverVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FastingSessionsCompanion copyWith({
    Value<String>? ownerUserId,
    Value<String>? id,
    Value<String>? plan,
    Value<String>? status,
    Value<int?>? activeSlot,
    Value<int>? startedAtUtcMs,
    Value<int>? targetEndAtUtcMs,
    Value<int?>? endedAtUtcMs,
    Value<String>? timeZoneId,
    Value<String>? startedLocalDay,
    Value<String>? targetEndLocalDay,
    Value<String?>? endedLocalDay,
    Value<int>? createdAtUtcMs,
    Value<int>? updatedAtUtcMs,
    Value<int>? serverVersion,
    Value<int>? rowid,
  }) {
    return FastingSessionsCompanion(
      ownerUserId: ownerUserId ?? this.ownerUserId,
      id: id ?? this.id,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      activeSlot: activeSlot ?? this.activeSlot,
      startedAtUtcMs: startedAtUtcMs ?? this.startedAtUtcMs,
      targetEndAtUtcMs: targetEndAtUtcMs ?? this.targetEndAtUtcMs,
      endedAtUtcMs: endedAtUtcMs ?? this.endedAtUtcMs,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      startedLocalDay: startedLocalDay ?? this.startedLocalDay,
      targetEndLocalDay: targetEndLocalDay ?? this.targetEndLocalDay,
      endedLocalDay: endedLocalDay ?? this.endedLocalDay,
      createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
      updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
      serverVersion: serverVersion ?? this.serverVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (plan.present) {
      map['plan'] = Variable<String>(plan.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (activeSlot.present) {
      map['active_slot'] = Variable<int>(activeSlot.value);
    }
    if (startedAtUtcMs.present) {
      map['started_at_utc_ms'] = Variable<int>(startedAtUtcMs.value);
    }
    if (targetEndAtUtcMs.present) {
      map['target_end_at_utc_ms'] = Variable<int>(targetEndAtUtcMs.value);
    }
    if (endedAtUtcMs.present) {
      map['ended_at_utc_ms'] = Variable<int>(endedAtUtcMs.value);
    }
    if (timeZoneId.present) {
      map['time_zone_id'] = Variable<String>(timeZoneId.value);
    }
    if (startedLocalDay.present) {
      map['started_local_day'] = Variable<String>(startedLocalDay.value);
    }
    if (targetEndLocalDay.present) {
      map['target_end_local_day'] = Variable<String>(targetEndLocalDay.value);
    }
    if (endedLocalDay.present) {
      map['ended_local_day'] = Variable<String>(endedLocalDay.value);
    }
    if (createdAtUtcMs.present) {
      map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs.value);
    }
    if (updatedAtUtcMs.present) {
      map['updated_at_utc_ms'] = Variable<int>(updatedAtUtcMs.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FastingSessionsCompanion(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('id: $id, ')
          ..write('plan: $plan, ')
          ..write('status: $status, ')
          ..write('activeSlot: $activeSlot, ')
          ..write('startedAtUtcMs: $startedAtUtcMs, ')
          ..write('targetEndAtUtcMs: $targetEndAtUtcMs, ')
          ..write('endedAtUtcMs: $endedAtUtcMs, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('startedLocalDay: $startedLocalDay, ')
          ..write('targetEndLocalDay: $targetEndLocalDay, ')
          ..write('endedLocalDay: $endedLocalDay, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('updatedAtUtcMs: $updatedAtUtcMs, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppPreferencesTableTable extends AppPreferencesTable
    with TableInfo<$AppPreferencesTableTable, AppPreferencesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPreferencesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _singletonIdMeta = const VerificationMeta(
    'singletonId',
  );
  @override
  late final GeneratedColumn<int> singletonId = GeneratedColumn<int>(
    'singleton_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dailyEnergyTargetKcalMeta =
      const VerificationMeta('dailyEnergyTargetKcal');
  @override
  late final GeneratedColumn<int> dailyEnergyTargetKcal = GeneratedColumn<int>(
    'daily_energy_target_kcal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedFastingPlanMeta =
      const VerificationMeta('selectedFastingPlan');
  @override
  late final GeneratedColumn<String> selectedFastingPlan =
      GeneratedColumn<String>(
        'selected_fasting_plan',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _fastingReminderEnabledMeta =
      const VerificationMeta('fastingReminderEnabled');
  @override
  late final GeneratedColumn<bool> fastingReminderEnabled =
      GeneratedColumn<bool>(
        'fasting_reminder_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("fasting_reminder_enabled" IN (0, 1))',
        ),
      );
  static const VerificationMeta _updatedAtUtcMsMeta = const VerificationMeta(
    'updatedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtcMs = GeneratedColumn<int>(
    'updated_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerUserId,
    singletonId,
    dailyEnergyTargetKcal,
    selectedFastingPlan,
    fastingReminderEnabled,
    updatedAtUtcMs,
    serverVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_preferences_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppPreferencesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('singleton_id')) {
      context.handle(
        _singletonIdMeta,
        singletonId.isAcceptableOrUnknown(
          data['singleton_id']!,
          _singletonIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_singletonIdMeta);
    }
    if (data.containsKey('daily_energy_target_kcal')) {
      context.handle(
        _dailyEnergyTargetKcalMeta,
        dailyEnergyTargetKcal.isAcceptableOrUnknown(
          data['daily_energy_target_kcal']!,
          _dailyEnergyTargetKcalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dailyEnergyTargetKcalMeta);
    }
    if (data.containsKey('selected_fasting_plan')) {
      context.handle(
        _selectedFastingPlanMeta,
        selectedFastingPlan.isAcceptableOrUnknown(
          data['selected_fasting_plan']!,
          _selectedFastingPlanMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedFastingPlanMeta);
    }
    if (data.containsKey('fasting_reminder_enabled')) {
      context.handle(
        _fastingReminderEnabledMeta,
        fastingReminderEnabled.isAcceptableOrUnknown(
          data['fasting_reminder_enabled']!,
          _fastingReminderEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fastingReminderEnabledMeta);
    }
    if (data.containsKey('updated_at_utc_ms')) {
      context.handle(
        _updatedAtUtcMsMeta,
        updatedAtUtcMs.isAcceptableOrUnknown(
          data['updated_at_utc_ms']!,
          _updatedAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMsMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerUserId, singletonId};
  @override
  AppPreferencesTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPreferencesTableData(
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      singletonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_id'],
      )!,
      dailyEnergyTargetKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_energy_target_kcal'],
      )!,
      selectedFastingPlan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_fasting_plan'],
      )!,
      fastingReminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fasting_reminder_enabled'],
      )!,
      updatedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc_ms'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
    );
  }

  @override
  $AppPreferencesTableTable createAlias(String alias) {
    return $AppPreferencesTableTable(attachedDatabase, alias);
  }
}

class AppPreferencesTableData extends DataClass
    implements Insertable<AppPreferencesTableData> {
  final String ownerUserId;
  final int singletonId;
  final int dailyEnergyTargetKcal;
  final String selectedFastingPlan;
  final bool fastingReminderEnabled;
  final int updatedAtUtcMs;
  final int serverVersion;
  const AppPreferencesTableData({
    required this.ownerUserId,
    required this.singletonId,
    required this.dailyEnergyTargetKcal,
    required this.selectedFastingPlan,
    required this.fastingReminderEnabled,
    required this.updatedAtUtcMs,
    required this.serverVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['singleton_id'] = Variable<int>(singletonId);
    map['daily_energy_target_kcal'] = Variable<int>(dailyEnergyTargetKcal);
    map['selected_fasting_plan'] = Variable<String>(selectedFastingPlan);
    map['fasting_reminder_enabled'] = Variable<bool>(fastingReminderEnabled);
    map['updated_at_utc_ms'] = Variable<int>(updatedAtUtcMs);
    map['server_version'] = Variable<int>(serverVersion);
    return map;
  }

  AppPreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return AppPreferencesTableCompanion(
      ownerUserId: Value(ownerUserId),
      singletonId: Value(singletonId),
      dailyEnergyTargetKcal: Value(dailyEnergyTargetKcal),
      selectedFastingPlan: Value(selectedFastingPlan),
      fastingReminderEnabled: Value(fastingReminderEnabled),
      updatedAtUtcMs: Value(updatedAtUtcMs),
      serverVersion: Value(serverVersion),
    );
  }

  factory AppPreferencesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPreferencesTableData(
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      singletonId: serializer.fromJson<int>(json['singletonId']),
      dailyEnergyTargetKcal: serializer.fromJson<int>(
        json['dailyEnergyTargetKcal'],
      ),
      selectedFastingPlan: serializer.fromJson<String>(
        json['selectedFastingPlan'],
      ),
      fastingReminderEnabled: serializer.fromJson<bool>(
        json['fastingReminderEnabled'],
      ),
      updatedAtUtcMs: serializer.fromJson<int>(json['updatedAtUtcMs']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'singletonId': serializer.toJson<int>(singletonId),
      'dailyEnergyTargetKcal': serializer.toJson<int>(dailyEnergyTargetKcal),
      'selectedFastingPlan': serializer.toJson<String>(selectedFastingPlan),
      'fastingReminderEnabled': serializer.toJson<bool>(fastingReminderEnabled),
      'updatedAtUtcMs': serializer.toJson<int>(updatedAtUtcMs),
      'serverVersion': serializer.toJson<int>(serverVersion),
    };
  }

  AppPreferencesTableData copyWith({
    String? ownerUserId,
    int? singletonId,
    int? dailyEnergyTargetKcal,
    String? selectedFastingPlan,
    bool? fastingReminderEnabled,
    int? updatedAtUtcMs,
    int? serverVersion,
  }) => AppPreferencesTableData(
    ownerUserId: ownerUserId ?? this.ownerUserId,
    singletonId: singletonId ?? this.singletonId,
    dailyEnergyTargetKcal: dailyEnergyTargetKcal ?? this.dailyEnergyTargetKcal,
    selectedFastingPlan: selectedFastingPlan ?? this.selectedFastingPlan,
    fastingReminderEnabled:
        fastingReminderEnabled ?? this.fastingReminderEnabled,
    updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
    serverVersion: serverVersion ?? this.serverVersion,
  );
  AppPreferencesTableData copyWithCompanion(AppPreferencesTableCompanion data) {
    return AppPreferencesTableData(
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      singletonId: data.singletonId.present
          ? data.singletonId.value
          : this.singletonId,
      dailyEnergyTargetKcal: data.dailyEnergyTargetKcal.present
          ? data.dailyEnergyTargetKcal.value
          : this.dailyEnergyTargetKcal,
      selectedFastingPlan: data.selectedFastingPlan.present
          ? data.selectedFastingPlan.value
          : this.selectedFastingPlan,
      fastingReminderEnabled: data.fastingReminderEnabled.present
          ? data.fastingReminderEnabled.value
          : this.fastingReminderEnabled,
      updatedAtUtcMs: data.updatedAtUtcMs.present
          ? data.updatedAtUtcMs.value
          : this.updatedAtUtcMs,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesTableData(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('singletonId: $singletonId, ')
          ..write('dailyEnergyTargetKcal: $dailyEnergyTargetKcal, ')
          ..write('selectedFastingPlan: $selectedFastingPlan, ')
          ..write('fastingReminderEnabled: $fastingReminderEnabled, ')
          ..write('updatedAtUtcMs: $updatedAtUtcMs, ')
          ..write('serverVersion: $serverVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerUserId,
    singletonId,
    dailyEnergyTargetKcal,
    selectedFastingPlan,
    fastingReminderEnabled,
    updatedAtUtcMs,
    serverVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPreferencesTableData &&
          other.ownerUserId == this.ownerUserId &&
          other.singletonId == this.singletonId &&
          other.dailyEnergyTargetKcal == this.dailyEnergyTargetKcal &&
          other.selectedFastingPlan == this.selectedFastingPlan &&
          other.fastingReminderEnabled == this.fastingReminderEnabled &&
          other.updatedAtUtcMs == this.updatedAtUtcMs &&
          other.serverVersion == this.serverVersion);
}

class AppPreferencesTableCompanion
    extends UpdateCompanion<AppPreferencesTableData> {
  final Value<String> ownerUserId;
  final Value<int> singletonId;
  final Value<int> dailyEnergyTargetKcal;
  final Value<String> selectedFastingPlan;
  final Value<bool> fastingReminderEnabled;
  final Value<int> updatedAtUtcMs;
  final Value<int> serverVersion;
  final Value<int> rowid;
  const AppPreferencesTableCompanion({
    this.ownerUserId = const Value.absent(),
    this.singletonId = const Value.absent(),
    this.dailyEnergyTargetKcal = const Value.absent(),
    this.selectedFastingPlan = const Value.absent(),
    this.fastingReminderEnabled = const Value.absent(),
    this.updatedAtUtcMs = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppPreferencesTableCompanion.insert({
    required String ownerUserId,
    required int singletonId,
    required int dailyEnergyTargetKcal,
    required String selectedFastingPlan,
    required bool fastingReminderEnabled,
    required int updatedAtUtcMs,
    this.serverVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerUserId = Value(ownerUserId),
       singletonId = Value(singletonId),
       dailyEnergyTargetKcal = Value(dailyEnergyTargetKcal),
       selectedFastingPlan = Value(selectedFastingPlan),
       fastingReminderEnabled = Value(fastingReminderEnabled),
       updatedAtUtcMs = Value(updatedAtUtcMs);
  static Insertable<AppPreferencesTableData> custom({
    Expression<String>? ownerUserId,
    Expression<int>? singletonId,
    Expression<int>? dailyEnergyTargetKcal,
    Expression<String>? selectedFastingPlan,
    Expression<bool>? fastingReminderEnabled,
    Expression<int>? updatedAtUtcMs,
    Expression<int>? serverVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (singletonId != null) 'singleton_id': singletonId,
      if (dailyEnergyTargetKcal != null)
        'daily_energy_target_kcal': dailyEnergyTargetKcal,
      if (selectedFastingPlan != null)
        'selected_fasting_plan': selectedFastingPlan,
      if (fastingReminderEnabled != null)
        'fasting_reminder_enabled': fastingReminderEnabled,
      if (updatedAtUtcMs != null) 'updated_at_utc_ms': updatedAtUtcMs,
      if (serverVersion != null) 'server_version': serverVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppPreferencesTableCompanion copyWith({
    Value<String>? ownerUserId,
    Value<int>? singletonId,
    Value<int>? dailyEnergyTargetKcal,
    Value<String>? selectedFastingPlan,
    Value<bool>? fastingReminderEnabled,
    Value<int>? updatedAtUtcMs,
    Value<int>? serverVersion,
    Value<int>? rowid,
  }) {
    return AppPreferencesTableCompanion(
      ownerUserId: ownerUserId ?? this.ownerUserId,
      singletonId: singletonId ?? this.singletonId,
      dailyEnergyTargetKcal:
          dailyEnergyTargetKcal ?? this.dailyEnergyTargetKcal,
      selectedFastingPlan: selectedFastingPlan ?? this.selectedFastingPlan,
      fastingReminderEnabled:
          fastingReminderEnabled ?? this.fastingReminderEnabled,
      updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
      serverVersion: serverVersion ?? this.serverVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (singletonId.present) {
      map['singleton_id'] = Variable<int>(singletonId.value);
    }
    if (dailyEnergyTargetKcal.present) {
      map['daily_energy_target_kcal'] = Variable<int>(
        dailyEnergyTargetKcal.value,
      );
    }
    if (selectedFastingPlan.present) {
      map['selected_fasting_plan'] = Variable<String>(
        selectedFastingPlan.value,
      );
    }
    if (fastingReminderEnabled.present) {
      map['fasting_reminder_enabled'] = Variable<bool>(
        fastingReminderEnabled.value,
      );
    }
    if (updatedAtUtcMs.present) {
      map['updated_at_utc_ms'] = Variable<int>(updatedAtUtcMs.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesTableCompanion(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('singletonId: $singletonId, ')
          ..write('dailyEnergyTargetKcal: $dailyEnergyTargetKcal, ')
          ..write('selectedFastingPlan: $selectedFastingPlan, ')
          ..write('fastingReminderEnabled: $fastingReminderEnabled, ')
          ..write('updatedAtUtcMs: $updatedAtUtcMs, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadVersionMeta = const VerificationMeta(
    'payloadVersion',
  );
  @override
  late final GeneratedColumn<int> payloadVersion = GeneratedColumn<int>(
    'payload_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedVersionMeta = const VerificationMeta(
    'expectedVersion',
  );
  @override
  late final GeneratedColumn<int> expectedVersion = GeneratedColumn<int>(
    'expected_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtUtcMsMeta = const VerificationMeta(
    'createdAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> createdAtUtcMs = GeneratedColumn<int>(
    'created_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtUtcMsMeta =
      const VerificationMeta('nextAttemptAtUtcMs');
  @override
  late final GeneratedColumn<int> nextAttemptAtUtcMs = GeneratedColumn<int>(
    'next_attempt_at_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerUserId,
    operationId,
    entityType,
    entityId,
    action,
    payloadVersion,
    payloadJson,
    expectedVersion,
    status,
    attemptCount,
    createdAtUtcMs,
    nextAttemptAtUtcMs,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload_version')) {
      context.handle(
        _payloadVersionMeta,
        payloadVersion.isAcceptableOrUnknown(
          data['payload_version']!,
          _payloadVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadVersionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('expected_version')) {
      context.handle(
        _expectedVersionMeta,
        expectedVersion.isAcceptableOrUnknown(
          data['expected_version']!,
          _expectedVersionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc_ms')) {
      context.handle(
        _createdAtUtcMsMeta,
        createdAtUtcMs.isAcceptableOrUnknown(
          data['created_at_utc_ms']!,
          _createdAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMsMeta);
    }
    if (data.containsKey('next_attempt_at_utc_ms')) {
      context.handle(
        _nextAttemptAtUtcMsMeta,
        nextAttemptAtUtcMs.isAcceptableOrUnknown(
          data['next_attempt_at_utc_ms']!,
          _nextAttemptAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerUserId, operationId};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      payloadVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_version'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      expectedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_version'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      createdAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_ms'],
      )!,
      nextAttemptAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at_utc_ms'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final String ownerUserId;
  final String operationId;
  final String entityType;
  final String entityId;
  final String action;
  final int payloadVersion;
  final String payloadJson;
  final int expectedVersion;
  final String status;
  final int attemptCount;
  final int createdAtUtcMs;
  final int? nextAttemptAtUtcMs;
  final String? lastError;
  const SyncOutboxData({
    required this.ownerUserId,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payloadVersion,
    required this.payloadJson,
    required this.expectedVersion,
    required this.status,
    required this.attemptCount,
    required this.createdAtUtcMs,
    this.nextAttemptAtUtcMs,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['operation_id'] = Variable<String>(operationId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['action'] = Variable<String>(action);
    map['payload_version'] = Variable<int>(payloadVersion);
    map['payload_json'] = Variable<String>(payloadJson);
    map['expected_version'] = Variable<int>(expectedVersion);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs);
    if (!nullToAbsent || nextAttemptAtUtcMs != null) {
      map['next_attempt_at_utc_ms'] = Variable<int>(nextAttemptAtUtcMs);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      ownerUserId: Value(ownerUserId),
      operationId: Value(operationId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      action: Value(action),
      payloadVersion: Value(payloadVersion),
      payloadJson: Value(payloadJson),
      expectedVersion: Value(expectedVersion),
      status: Value(status),
      attemptCount: Value(attemptCount),
      createdAtUtcMs: Value(createdAtUtcMs),
      nextAttemptAtUtcMs: nextAttemptAtUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAtUtcMs),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      action: serializer.fromJson<String>(json['action']),
      payloadVersion: serializer.fromJson<int>(json['payloadVersion']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      expectedVersion: serializer.fromJson<int>(json['expectedVersion']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      createdAtUtcMs: serializer.fromJson<int>(json['createdAtUtcMs']),
      nextAttemptAtUtcMs: serializer.fromJson<int?>(json['nextAttemptAtUtcMs']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'operationId': serializer.toJson<String>(operationId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'action': serializer.toJson<String>(action),
      'payloadVersion': serializer.toJson<int>(payloadVersion),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'expectedVersion': serializer.toJson<int>(expectedVersion),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'createdAtUtcMs': serializer.toJson<int>(createdAtUtcMs),
      'nextAttemptAtUtcMs': serializer.toJson<int?>(nextAttemptAtUtcMs),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncOutboxData copyWith({
    String? ownerUserId,
    String? operationId,
    String? entityType,
    String? entityId,
    String? action,
    int? payloadVersion,
    String? payloadJson,
    int? expectedVersion,
    String? status,
    int? attemptCount,
    int? createdAtUtcMs,
    Value<int?> nextAttemptAtUtcMs = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => SyncOutboxData(
    ownerUserId: ownerUserId ?? this.ownerUserId,
    operationId: operationId ?? this.operationId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    action: action ?? this.action,
    payloadVersion: payloadVersion ?? this.payloadVersion,
    payloadJson: payloadJson ?? this.payloadJson,
    expectedVersion: expectedVersion ?? this.expectedVersion,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
    nextAttemptAtUtcMs: nextAttemptAtUtcMs.present
        ? nextAttemptAtUtcMs.value
        : this.nextAttemptAtUtcMs,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      action: data.action.present ? data.action.value : this.action,
      payloadVersion: data.payloadVersion.present
          ? data.payloadVersion.value
          : this.payloadVersion,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      expectedVersion: data.expectedVersion.present
          ? data.expectedVersion.value
          : this.expectedVersion,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      createdAtUtcMs: data.createdAtUtcMs.present
          ? data.createdAtUtcMs.value
          : this.createdAtUtcMs,
      nextAttemptAtUtcMs: data.nextAttemptAtUtcMs.present
          ? data.nextAttemptAtUtcMs.value
          : this.nextAttemptAtUtcMs,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('payloadVersion: $payloadVersion, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('nextAttemptAtUtcMs: $nextAttemptAtUtcMs, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerUserId,
    operationId,
    entityType,
    entityId,
    action,
    payloadVersion,
    payloadJson,
    expectedVersion,
    status,
    attemptCount,
    createdAtUtcMs,
    nextAttemptAtUtcMs,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.ownerUserId == this.ownerUserId &&
          other.operationId == this.operationId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.action == this.action &&
          other.payloadVersion == this.payloadVersion &&
          other.payloadJson == this.payloadJson &&
          other.expectedVersion == this.expectedVersion &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.createdAtUtcMs == this.createdAtUtcMs &&
          other.nextAttemptAtUtcMs == this.nextAttemptAtUtcMs &&
          other.lastError == this.lastError);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<String> ownerUserId;
  final Value<String> operationId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> action;
  final Value<int> payloadVersion;
  final Value<String> payloadJson;
  final Value<int> expectedVersion;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<int> createdAtUtcMs;
  final Value<int?> nextAttemptAtUtcMs;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.ownerUserId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.action = const Value.absent(),
    this.payloadVersion = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.expectedVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.createdAtUtcMs = const Value.absent(),
    this.nextAttemptAtUtcMs = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String ownerUserId,
    required String operationId,
    required String entityType,
    required String entityId,
    required String action,
    required int payloadVersion,
    required String payloadJson,
    this.expectedVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    required int createdAtUtcMs,
    this.nextAttemptAtUtcMs = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerUserId = Value(ownerUserId),
       operationId = Value(operationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       action = Value(action),
       payloadVersion = Value(payloadVersion),
       payloadJson = Value(payloadJson),
       createdAtUtcMs = Value(createdAtUtcMs);
  static Insertable<SyncOutboxData> custom({
    Expression<String>? ownerUserId,
    Expression<String>? operationId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? action,
    Expression<int>? payloadVersion,
    Expression<String>? payloadJson,
    Expression<int>? expectedVersion,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<int>? createdAtUtcMs,
    Expression<int>? nextAttemptAtUtcMs,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (operationId != null) 'operation_id': operationId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (action != null) 'action': action,
      if (payloadVersion != null) 'payload_version': payloadVersion,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (expectedVersion != null) 'expected_version': expectedVersion,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (createdAtUtcMs != null) 'created_at_utc_ms': createdAtUtcMs,
      if (nextAttemptAtUtcMs != null)
        'next_attempt_at_utc_ms': nextAttemptAtUtcMs,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<String>? ownerUserId,
    Value<String>? operationId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? action,
    Value<int>? payloadVersion,
    Value<String>? payloadJson,
    Value<int>? expectedVersion,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<int>? createdAtUtcMs,
    Value<int?>? nextAttemptAtUtcMs,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return SyncOutboxCompanion(
      ownerUserId: ownerUserId ?? this.ownerUserId,
      operationId: operationId ?? this.operationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      payloadVersion: payloadVersion ?? this.payloadVersion,
      payloadJson: payloadJson ?? this.payloadJson,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
      nextAttemptAtUtcMs: nextAttemptAtUtcMs ?? this.nextAttemptAtUtcMs,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payloadVersion.present) {
      map['payload_version'] = Variable<int>(payloadVersion.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (expectedVersion.present) {
      map['expected_version'] = Variable<int>(expectedVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (createdAtUtcMs.present) {
      map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs.value);
    }
    if (nextAttemptAtUtcMs.present) {
      map['next_attempt_at_utc_ms'] = Variable<int>(nextAttemptAtUtcMs.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('payloadVersion: $payloadVersion, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('nextAttemptAtUtcMs: $nextAttemptAtUtcMs, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<int> cursor = GeneratedColumn<int>(
    'cursor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtUtcMsMeta = const VerificationMeta(
    'updatedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtcMs = GeneratedColumn<int>(
    'updated_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [ownerUserId, cursor, updatedAtUtcMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('updated_at_utc_ms')) {
      context.handle(
        _updatedAtUtcMsMeta,
        updatedAtUtcMs.isAcceptableOrUnknown(
          data['updated_at_utc_ms']!,
          _updatedAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerUserId};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cursor'],
      )!,
      updatedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc_ms'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String ownerUserId;
  final int cursor;
  final int updatedAtUtcMs;
  const SyncStateData({
    required this.ownerUserId,
    required this.cursor,
    required this.updatedAtUtcMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['cursor'] = Variable<int>(cursor);
    map['updated_at_utc_ms'] = Variable<int>(updatedAtUtcMs);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      ownerUserId: Value(ownerUserId),
      cursor: Value(cursor),
      updatedAtUtcMs: Value(updatedAtUtcMs),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      cursor: serializer.fromJson<int>(json['cursor']),
      updatedAtUtcMs: serializer.fromJson<int>(json['updatedAtUtcMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'cursor': serializer.toJson<int>(cursor),
      'updatedAtUtcMs': serializer.toJson<int>(updatedAtUtcMs),
    };
  }

  SyncStateData copyWith({
    String? ownerUserId,
    int? cursor,
    int? updatedAtUtcMs,
  }) => SyncStateData(
    ownerUserId: ownerUserId ?? this.ownerUserId,
    cursor: cursor ?? this.cursor,
    updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      updatedAtUtcMs: data.updatedAtUtcMs.present
          ? data.updatedAtUtcMs.value
          : this.updatedAtUtcMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('cursor: $cursor, ')
          ..write('updatedAtUtcMs: $updatedAtUtcMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerUserId, cursor, updatedAtUtcMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.ownerUserId == this.ownerUserId &&
          other.cursor == this.cursor &&
          other.updatedAtUtcMs == this.updatedAtUtcMs);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> ownerUserId;
  final Value<int> cursor;
  final Value<int> updatedAtUtcMs;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.ownerUserId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.updatedAtUtcMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String ownerUserId,
    this.cursor = const Value.absent(),
    required int updatedAtUtcMs,
    this.rowid = const Value.absent(),
  }) : ownerUserId = Value(ownerUserId),
       updatedAtUtcMs = Value(updatedAtUtcMs);
  static Insertable<SyncStateData> custom({
    Expression<String>? ownerUserId,
    Expression<int>? cursor,
    Expression<int>? updatedAtUtcMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (cursor != null) 'cursor': cursor,
      if (updatedAtUtcMs != null) 'updated_at_utc_ms': updatedAtUtcMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? ownerUserId,
    Value<int>? cursor,
    Value<int>? updatedAtUtcMs,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      ownerUserId: ownerUserId ?? this.ownerUserId,
      cursor: cursor ?? this.cursor,
      updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<int>(cursor.value);
    }
    if (updatedAtUtcMs.present) {
      map['updated_at_utc_ms'] = Variable<int>(updatedAtUtcMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('cursor: $cursor, ')
          ..write('updatedAtUtcMs: $updatedAtUtcMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MealLogsTable mealLogs = $MealLogsTable(this);
  late final $MealItemsTable mealItems = $MealItemsTable(this);
  late final $FastingSessionsTable fastingSessions = $FastingSessionsTable(
    this,
  );
  late final $AppPreferencesTableTable appPreferencesTable =
      $AppPreferencesTableTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mealLogs,
    mealItems,
    fastingSessions,
    appPreferencesTable,
    syncOutbox,
    syncState,
  ];
}

typedef $$MealLogsTableCreateCompanionBuilder =
    MealLogsCompanion Function({
      required String ownerUserId,
      required String id,
      required String mealType,
      required String source,
      required int occurredAtUtcMs,
      required String timeZoneId,
      required String localDay,
      required bool isWithinEatingWindow,
      required int createdAtUtcMs,
      required int updatedAtUtcMs,
      Value<int?> deletedAtUtcMs,
      Value<int> serverVersion,
      Value<int> rowid,
    });
typedef $$MealLogsTableUpdateCompanionBuilder =
    MealLogsCompanion Function({
      Value<String> ownerUserId,
      Value<String> id,
      Value<String> mealType,
      Value<String> source,
      Value<int> occurredAtUtcMs,
      Value<String> timeZoneId,
      Value<String> localDay,
      Value<bool> isWithinEatingWindow,
      Value<int> createdAtUtcMs,
      Value<int> updatedAtUtcMs,
      Value<int?> deletedAtUtcMs,
      Value<int> serverVersion,
      Value<int> rowid,
    });

class $$MealLogsTableFilterComposer
    extends Composer<_$AppDatabase, $MealLogsTable> {
  $$MealLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAtUtcMs => $composableBuilder(
    column: $table.occurredAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isWithinEatingWindow => $composableBuilder(
    column: $table.isWithinEatingWindow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtcMs => $composableBuilder(
    column: $table.deletedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MealLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealLogsTable> {
  $$MealLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAtUtcMs => $composableBuilder(
    column: $table.occurredAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isWithinEatingWindow => $composableBuilder(
    column: $table.isWithinEatingWindow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtcMs => $composableBuilder(
    column: $table.deletedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealLogsTable> {
  $$MealLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mealType =>
      $composableBuilder(column: $table.mealType, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get occurredAtUtcMs => $composableBuilder(
    column: $table.occurredAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<bool> get isWithinEatingWindow => $composableBuilder(
    column: $table.isWithinEatingWindow,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtcMs => $composableBuilder(
    column: $table.deletedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );
}

class $$MealLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealLogsTable,
          MealLog,
          $$MealLogsTableFilterComposer,
          $$MealLogsTableOrderingComposer,
          $$MealLogsTableAnnotationComposer,
          $$MealLogsTableCreateCompanionBuilder,
          $$MealLogsTableUpdateCompanionBuilder,
          (MealLog, BaseReferences<_$AppDatabase, $MealLogsTable, MealLog>),
          MealLog,
          PrefetchHooks Function()
        > {
  $$MealLogsTableTableManager(_$AppDatabase db, $MealLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerUserId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> mealType = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> occurredAtUtcMs = const Value.absent(),
                Value<String> timeZoneId = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<bool> isWithinEatingWindow = const Value.absent(),
                Value<int> createdAtUtcMs = const Value.absent(),
                Value<int> updatedAtUtcMs = const Value.absent(),
                Value<int?> deletedAtUtcMs = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealLogsCompanion(
                ownerUserId: ownerUserId,
                id: id,
                mealType: mealType,
                source: source,
                occurredAtUtcMs: occurredAtUtcMs,
                timeZoneId: timeZoneId,
                localDay: localDay,
                isWithinEatingWindow: isWithinEatingWindow,
                createdAtUtcMs: createdAtUtcMs,
                updatedAtUtcMs: updatedAtUtcMs,
                deletedAtUtcMs: deletedAtUtcMs,
                serverVersion: serverVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerUserId,
                required String id,
                required String mealType,
                required String source,
                required int occurredAtUtcMs,
                required String timeZoneId,
                required String localDay,
                required bool isWithinEatingWindow,
                required int createdAtUtcMs,
                required int updatedAtUtcMs,
                Value<int?> deletedAtUtcMs = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealLogsCompanion.insert(
                ownerUserId: ownerUserId,
                id: id,
                mealType: mealType,
                source: source,
                occurredAtUtcMs: occurredAtUtcMs,
                timeZoneId: timeZoneId,
                localDay: localDay,
                isWithinEatingWindow: isWithinEatingWindow,
                createdAtUtcMs: createdAtUtcMs,
                updatedAtUtcMs: updatedAtUtcMs,
                deletedAtUtcMs: deletedAtUtcMs,
                serverVersion: serverVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MealLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealLogsTable,
      MealLog,
      $$MealLogsTableFilterComposer,
      $$MealLogsTableOrderingComposer,
      $$MealLogsTableAnnotationComposer,
      $$MealLogsTableCreateCompanionBuilder,
      $$MealLogsTableUpdateCompanionBuilder,
      (MealLog, BaseReferences<_$AppDatabase, $MealLogsTable, MealLog>),
      MealLog,
      PrefetchHooks Function()
    >;
typedef $$MealItemsTableCreateCompanionBuilder =
    MealItemsCompanion Function({
      required String ownerUserId,
      required String id,
      required String mealLogId,
      required String name,
      required int servingMilli,
      required int energyKcal,
      required int proteinMg,
      required int carbsMg,
      required int fatMg,
      Value<String?> imageReference,
      required int createdAtUtcMs,
      required int updatedAtUtcMs,
      Value<int> rowid,
    });
typedef $$MealItemsTableUpdateCompanionBuilder =
    MealItemsCompanion Function({
      Value<String> ownerUserId,
      Value<String> id,
      Value<String> mealLogId,
      Value<String> name,
      Value<int> servingMilli,
      Value<int> energyKcal,
      Value<int> proteinMg,
      Value<int> carbsMg,
      Value<int> fatMg,
      Value<String?> imageReference,
      Value<int> createdAtUtcMs,
      Value<int> updatedAtUtcMs,
      Value<int> rowid,
    });

class $$MealItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MealItemsTable> {
  $$MealItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealLogId => $composableBuilder(
    column: $table.mealLogId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get servingMilli => $composableBuilder(
    column: $table.servingMilli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energyKcal => $composableBuilder(
    column: $table.energyKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proteinMg => $composableBuilder(
    column: $table.proteinMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carbsMg => $composableBuilder(
    column: $table.carbsMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fatMg => $composableBuilder(
    column: $table.fatMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageReference => $composableBuilder(
    column: $table.imageReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MealItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealItemsTable> {
  $$MealItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealLogId => $composableBuilder(
    column: $table.mealLogId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get servingMilli => $composableBuilder(
    column: $table.servingMilli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energyKcal => $composableBuilder(
    column: $table.energyKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proteinMg => $composableBuilder(
    column: $table.proteinMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carbsMg => $composableBuilder(
    column: $table.carbsMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fatMg => $composableBuilder(
    column: $table.fatMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageReference => $composableBuilder(
    column: $table.imageReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealItemsTable> {
  $$MealItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mealLogId =>
      $composableBuilder(column: $table.mealLogId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get servingMilli => $composableBuilder(
    column: $table.servingMilli,
    builder: (column) => column,
  );

  GeneratedColumn<int> get energyKcal => $composableBuilder(
    column: $table.energyKcal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get proteinMg =>
      $composableBuilder(column: $table.proteinMg, builder: (column) => column);

  GeneratedColumn<int> get carbsMg =>
      $composableBuilder(column: $table.carbsMg, builder: (column) => column);

  GeneratedColumn<int> get fatMg =>
      $composableBuilder(column: $table.fatMg, builder: (column) => column);

  GeneratedColumn<String> get imageReference => $composableBuilder(
    column: $table.imageReference,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => column,
  );
}

class $$MealItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealItemsTable,
          MealItem,
          $$MealItemsTableFilterComposer,
          $$MealItemsTableOrderingComposer,
          $$MealItemsTableAnnotationComposer,
          $$MealItemsTableCreateCompanionBuilder,
          $$MealItemsTableUpdateCompanionBuilder,
          (MealItem, BaseReferences<_$AppDatabase, $MealItemsTable, MealItem>),
          MealItem,
          PrefetchHooks Function()
        > {
  $$MealItemsTableTableManager(_$AppDatabase db, $MealItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerUserId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> mealLogId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> servingMilli = const Value.absent(),
                Value<int> energyKcal = const Value.absent(),
                Value<int> proteinMg = const Value.absent(),
                Value<int> carbsMg = const Value.absent(),
                Value<int> fatMg = const Value.absent(),
                Value<String?> imageReference = const Value.absent(),
                Value<int> createdAtUtcMs = const Value.absent(),
                Value<int> updatedAtUtcMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealItemsCompanion(
                ownerUserId: ownerUserId,
                id: id,
                mealLogId: mealLogId,
                name: name,
                servingMilli: servingMilli,
                energyKcal: energyKcal,
                proteinMg: proteinMg,
                carbsMg: carbsMg,
                fatMg: fatMg,
                imageReference: imageReference,
                createdAtUtcMs: createdAtUtcMs,
                updatedAtUtcMs: updatedAtUtcMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerUserId,
                required String id,
                required String mealLogId,
                required String name,
                required int servingMilli,
                required int energyKcal,
                required int proteinMg,
                required int carbsMg,
                required int fatMg,
                Value<String?> imageReference = const Value.absent(),
                required int createdAtUtcMs,
                required int updatedAtUtcMs,
                Value<int> rowid = const Value.absent(),
              }) => MealItemsCompanion.insert(
                ownerUserId: ownerUserId,
                id: id,
                mealLogId: mealLogId,
                name: name,
                servingMilli: servingMilli,
                energyKcal: energyKcal,
                proteinMg: proteinMg,
                carbsMg: carbsMg,
                fatMg: fatMg,
                imageReference: imageReference,
                createdAtUtcMs: createdAtUtcMs,
                updatedAtUtcMs: updatedAtUtcMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MealItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealItemsTable,
      MealItem,
      $$MealItemsTableFilterComposer,
      $$MealItemsTableOrderingComposer,
      $$MealItemsTableAnnotationComposer,
      $$MealItemsTableCreateCompanionBuilder,
      $$MealItemsTableUpdateCompanionBuilder,
      (MealItem, BaseReferences<_$AppDatabase, $MealItemsTable, MealItem>),
      MealItem,
      PrefetchHooks Function()
    >;
typedef $$FastingSessionsTableCreateCompanionBuilder =
    FastingSessionsCompanion Function({
      required String ownerUserId,
      required String id,
      required String plan,
      required String status,
      Value<int?> activeSlot,
      required int startedAtUtcMs,
      required int targetEndAtUtcMs,
      Value<int?> endedAtUtcMs,
      required String timeZoneId,
      required String startedLocalDay,
      required String targetEndLocalDay,
      Value<String?> endedLocalDay,
      required int createdAtUtcMs,
      required int updatedAtUtcMs,
      Value<int> serverVersion,
      Value<int> rowid,
    });
typedef $$FastingSessionsTableUpdateCompanionBuilder =
    FastingSessionsCompanion Function({
      Value<String> ownerUserId,
      Value<String> id,
      Value<String> plan,
      Value<String> status,
      Value<int?> activeSlot,
      Value<int> startedAtUtcMs,
      Value<int> targetEndAtUtcMs,
      Value<int?> endedAtUtcMs,
      Value<String> timeZoneId,
      Value<String> startedLocalDay,
      Value<String> targetEndLocalDay,
      Value<String?> endedLocalDay,
      Value<int> createdAtUtcMs,
      Value<int> updatedAtUtcMs,
      Value<int> serverVersion,
      Value<int> rowid,
    });

class $$FastingSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $FastingSessionsTable> {
  $$FastingSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plan => $composableBuilder(
    column: $table.plan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeSlot => $composableBuilder(
    column: $table.activeSlot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUtcMs => $composableBuilder(
    column: $table.startedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetEndAtUtcMs => $composableBuilder(
    column: $table.targetEndAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtUtcMs => $composableBuilder(
    column: $table.endedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedLocalDay => $composableBuilder(
    column: $table.startedLocalDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetEndLocalDay => $composableBuilder(
    column: $table.targetEndLocalDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endedLocalDay => $composableBuilder(
    column: $table.endedLocalDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FastingSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FastingSessionsTable> {
  $$FastingSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plan => $composableBuilder(
    column: $table.plan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeSlot => $composableBuilder(
    column: $table.activeSlot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUtcMs => $composableBuilder(
    column: $table.startedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetEndAtUtcMs => $composableBuilder(
    column: $table.targetEndAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtUtcMs => $composableBuilder(
    column: $table.endedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedLocalDay => $composableBuilder(
    column: $table.startedLocalDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetEndLocalDay => $composableBuilder(
    column: $table.targetEndLocalDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endedLocalDay => $composableBuilder(
    column: $table.endedLocalDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FastingSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FastingSessionsTable> {
  $$FastingSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get plan =>
      $composableBuilder(column: $table.plan, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get activeSlot => $composableBuilder(
    column: $table.activeSlot,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAtUtcMs => $composableBuilder(
    column: $table.startedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetEndAtUtcMs => $composableBuilder(
    column: $table.targetEndAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtUtcMs => $composableBuilder(
    column: $table.endedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startedLocalDay => $composableBuilder(
    column: $table.startedLocalDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetEndLocalDay => $composableBuilder(
    column: $table.targetEndLocalDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endedLocalDay => $composableBuilder(
    column: $table.endedLocalDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );
}

class $$FastingSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FastingSessionsTable,
          FastingSession,
          $$FastingSessionsTableFilterComposer,
          $$FastingSessionsTableOrderingComposer,
          $$FastingSessionsTableAnnotationComposer,
          $$FastingSessionsTableCreateCompanionBuilder,
          $$FastingSessionsTableUpdateCompanionBuilder,
          (
            FastingSession,
            BaseReferences<
              _$AppDatabase,
              $FastingSessionsTable,
              FastingSession
            >,
          ),
          FastingSession,
          PrefetchHooks Function()
        > {
  $$FastingSessionsTableTableManager(
    _$AppDatabase db,
    $FastingSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FastingSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FastingSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FastingSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerUserId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> plan = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> activeSlot = const Value.absent(),
                Value<int> startedAtUtcMs = const Value.absent(),
                Value<int> targetEndAtUtcMs = const Value.absent(),
                Value<int?> endedAtUtcMs = const Value.absent(),
                Value<String> timeZoneId = const Value.absent(),
                Value<String> startedLocalDay = const Value.absent(),
                Value<String> targetEndLocalDay = const Value.absent(),
                Value<String?> endedLocalDay = const Value.absent(),
                Value<int> createdAtUtcMs = const Value.absent(),
                Value<int> updatedAtUtcMs = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FastingSessionsCompanion(
                ownerUserId: ownerUserId,
                id: id,
                plan: plan,
                status: status,
                activeSlot: activeSlot,
                startedAtUtcMs: startedAtUtcMs,
                targetEndAtUtcMs: targetEndAtUtcMs,
                endedAtUtcMs: endedAtUtcMs,
                timeZoneId: timeZoneId,
                startedLocalDay: startedLocalDay,
                targetEndLocalDay: targetEndLocalDay,
                endedLocalDay: endedLocalDay,
                createdAtUtcMs: createdAtUtcMs,
                updatedAtUtcMs: updatedAtUtcMs,
                serverVersion: serverVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerUserId,
                required String id,
                required String plan,
                required String status,
                Value<int?> activeSlot = const Value.absent(),
                required int startedAtUtcMs,
                required int targetEndAtUtcMs,
                Value<int?> endedAtUtcMs = const Value.absent(),
                required String timeZoneId,
                required String startedLocalDay,
                required String targetEndLocalDay,
                Value<String?> endedLocalDay = const Value.absent(),
                required int createdAtUtcMs,
                required int updatedAtUtcMs,
                Value<int> serverVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FastingSessionsCompanion.insert(
                ownerUserId: ownerUserId,
                id: id,
                plan: plan,
                status: status,
                activeSlot: activeSlot,
                startedAtUtcMs: startedAtUtcMs,
                targetEndAtUtcMs: targetEndAtUtcMs,
                endedAtUtcMs: endedAtUtcMs,
                timeZoneId: timeZoneId,
                startedLocalDay: startedLocalDay,
                targetEndLocalDay: targetEndLocalDay,
                endedLocalDay: endedLocalDay,
                createdAtUtcMs: createdAtUtcMs,
                updatedAtUtcMs: updatedAtUtcMs,
                serverVersion: serverVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FastingSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FastingSessionsTable,
      FastingSession,
      $$FastingSessionsTableFilterComposer,
      $$FastingSessionsTableOrderingComposer,
      $$FastingSessionsTableAnnotationComposer,
      $$FastingSessionsTableCreateCompanionBuilder,
      $$FastingSessionsTableUpdateCompanionBuilder,
      (
        FastingSession,
        BaseReferences<_$AppDatabase, $FastingSessionsTable, FastingSession>,
      ),
      FastingSession,
      PrefetchHooks Function()
    >;
typedef $$AppPreferencesTableTableCreateCompanionBuilder =
    AppPreferencesTableCompanion Function({
      required String ownerUserId,
      required int singletonId,
      required int dailyEnergyTargetKcal,
      required String selectedFastingPlan,
      required bool fastingReminderEnabled,
      required int updatedAtUtcMs,
      Value<int> serverVersion,
      Value<int> rowid,
    });
typedef $$AppPreferencesTableTableUpdateCompanionBuilder =
    AppPreferencesTableCompanion Function({
      Value<String> ownerUserId,
      Value<int> singletonId,
      Value<int> dailyEnergyTargetKcal,
      Value<String> selectedFastingPlan,
      Value<bool> fastingReminderEnabled,
      Value<int> updatedAtUtcMs,
      Value<int> serverVersion,
      Value<int> rowid,
    });

class $$AppPreferencesTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppPreferencesTableTable> {
  $$AppPreferencesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyEnergyTargetKcal => $composableBuilder(
    column: $table.dailyEnergyTargetKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedFastingPlan => $composableBuilder(
    column: $table.selectedFastingPlan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fastingReminderEnabled => $composableBuilder(
    column: $table.fastingReminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppPreferencesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppPreferencesTableTable> {
  $$AppPreferencesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyEnergyTargetKcal => $composableBuilder(
    column: $table.dailyEnergyTargetKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedFastingPlan => $composableBuilder(
    column: $table.selectedFastingPlan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fastingReminderEnabled => $composableBuilder(
    column: $table.fastingReminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppPreferencesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppPreferencesTableTable> {
  $$AppPreferencesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyEnergyTargetKcal => $composableBuilder(
    column: $table.dailyEnergyTargetKcal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedFastingPlan => $composableBuilder(
    column: $table.selectedFastingPlan,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get fastingReminderEnabled => $composableBuilder(
    column: $table.fastingReminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );
}

class $$AppPreferencesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppPreferencesTableTable,
          AppPreferencesTableData,
          $$AppPreferencesTableTableFilterComposer,
          $$AppPreferencesTableTableOrderingComposer,
          $$AppPreferencesTableTableAnnotationComposer,
          $$AppPreferencesTableTableCreateCompanionBuilder,
          $$AppPreferencesTableTableUpdateCompanionBuilder,
          (
            AppPreferencesTableData,
            BaseReferences<
              _$AppDatabase,
              $AppPreferencesTableTable,
              AppPreferencesTableData
            >,
          ),
          AppPreferencesTableData,
          PrefetchHooks Function()
        > {
  $$AppPreferencesTableTableTableManager(
    _$AppDatabase db,
    $AppPreferencesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPreferencesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPreferencesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AppPreferencesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerUserId = const Value.absent(),
                Value<int> singletonId = const Value.absent(),
                Value<int> dailyEnergyTargetKcal = const Value.absent(),
                Value<String> selectedFastingPlan = const Value.absent(),
                Value<bool> fastingReminderEnabled = const Value.absent(),
                Value<int> updatedAtUtcMs = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesTableCompanion(
                ownerUserId: ownerUserId,
                singletonId: singletonId,
                dailyEnergyTargetKcal: dailyEnergyTargetKcal,
                selectedFastingPlan: selectedFastingPlan,
                fastingReminderEnabled: fastingReminderEnabled,
                updatedAtUtcMs: updatedAtUtcMs,
                serverVersion: serverVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerUserId,
                required int singletonId,
                required int dailyEnergyTargetKcal,
                required String selectedFastingPlan,
                required bool fastingReminderEnabled,
                required int updatedAtUtcMs,
                Value<int> serverVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesTableCompanion.insert(
                ownerUserId: ownerUserId,
                singletonId: singletonId,
                dailyEnergyTargetKcal: dailyEnergyTargetKcal,
                selectedFastingPlan: selectedFastingPlan,
                fastingReminderEnabled: fastingReminderEnabled,
                updatedAtUtcMs: updatedAtUtcMs,
                serverVersion: serverVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppPreferencesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppPreferencesTableTable,
      AppPreferencesTableData,
      $$AppPreferencesTableTableFilterComposer,
      $$AppPreferencesTableTableOrderingComposer,
      $$AppPreferencesTableTableAnnotationComposer,
      $$AppPreferencesTableTableCreateCompanionBuilder,
      $$AppPreferencesTableTableUpdateCompanionBuilder,
      (
        AppPreferencesTableData,
        BaseReferences<
          _$AppDatabase,
          $AppPreferencesTableTable,
          AppPreferencesTableData
        >,
      ),
      AppPreferencesTableData,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder =
    SyncOutboxCompanion Function({
      required String ownerUserId,
      required String operationId,
      required String entityType,
      required String entityId,
      required String action,
      required int payloadVersion,
      required String payloadJson,
      Value<int> expectedVersion,
      Value<String> status,
      Value<int> attemptCount,
      required int createdAtUtcMs,
      Value<int?> nextAttemptAtUtcMs,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$SyncOutboxTableUpdateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<String> ownerUserId,
      Value<String> operationId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> action,
      Value<int> payloadVersion,
      Value<String> payloadJson,
      Value<int> expectedVersion,
      Value<String> status,
      Value<int> attemptCount,
      Value<int> createdAtUtcMs,
      Value<int?> nextAttemptAtUtcMs,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAtUtcMs => $composableBuilder(
    column: $table.nextAttemptAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAtUtcMs => $composableBuilder(
    column: $table.nextAttemptAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextAttemptAtUtcMs => $composableBuilder(
    column: $table.nextAttemptAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          SyncOutboxData,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxData,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>,
          ),
          SyncOutboxData,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerUserId = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<int> payloadVersion = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> expectedVersion = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<int> createdAtUtcMs = const Value.absent(),
                Value<int?> nextAttemptAtUtcMs = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion(
                ownerUserId: ownerUserId,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                action: action,
                payloadVersion: payloadVersion,
                payloadJson: payloadJson,
                expectedVersion: expectedVersion,
                status: status,
                attemptCount: attemptCount,
                createdAtUtcMs: createdAtUtcMs,
                nextAttemptAtUtcMs: nextAttemptAtUtcMs,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerUserId,
                required String operationId,
                required String entityType,
                required String entityId,
                required String action,
                required int payloadVersion,
                required String payloadJson,
                Value<int> expectedVersion = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                required int createdAtUtcMs,
                Value<int?> nextAttemptAtUtcMs = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                ownerUserId: ownerUserId,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                action: action,
                payloadVersion: payloadVersion,
                payloadJson: payloadJson,
                expectedVersion: expectedVersion,
                status: status,
                attemptCount: attemptCount,
                createdAtUtcMs: createdAtUtcMs,
                nextAttemptAtUtcMs: nextAttemptAtUtcMs,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      SyncOutboxData,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxData,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>,
      ),
      SyncOutboxData,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String ownerUserId,
      Value<int> cursor,
      required int updatedAtUtcMs,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> ownerUserId,
      Value<int> cursor,
      Value<int> updatedAtUtcMs,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<int> get updatedAtUtcMs => $composableBuilder(
    column: $table.updatedAtUtcMs,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerUserId = const Value.absent(),
                Value<int> cursor = const Value.absent(),
                Value<int> updatedAtUtcMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                ownerUserId: ownerUserId,
                cursor: cursor,
                updatedAtUtcMs: updatedAtUtcMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerUserId,
                Value<int> cursor = const Value.absent(),
                required int updatedAtUtcMs,
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                ownerUserId: ownerUserId,
                cursor: cursor,
                updatedAtUtcMs: updatedAtUtcMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MealLogsTableTableManager get mealLogs =>
      $$MealLogsTableTableManager(_db, _db.mealLogs);
  $$MealItemsTableTableManager get mealItems =>
      $$MealItemsTableTableManager(_db, _db.mealItems);
  $$FastingSessionsTableTableManager get fastingSessions =>
      $$FastingSessionsTableTableManager(_db, _db.fastingSessions);
  $$AppPreferencesTableTableTableManager get appPreferencesTable =>
      $$AppPreferencesTableTableTableManager(_db, _db.appPreferencesTable);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
