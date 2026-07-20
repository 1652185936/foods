// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_export_correction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountExportCorrection _$AccountExportCorrectionFromJson(
  Map<String, dynamic> json,
) => AccountExportCorrection(
  baseVersion: (json['baseVersion'] as num).toInt(),
  createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
  id: json['id'] as String,
  items: (json['items'] as List<dynamic>)
      .map(
        (e) => AccountExportCorrectionItem.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
);

Map<String, dynamic> _$AccountExportCorrectionToJson(
  AccountExportCorrection instance,
) => <String, dynamic>{
  'baseVersion': instance.baseVersion,
  'createdAtUtc': instance.createdAtUtc.toIso8601String(),
  'id': instance.id,
  'items': instance.items,
};
