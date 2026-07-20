// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'sync_operation_input.dart';

part 'sync_push_input.g.dart';

@JsonSerializable()
class SyncPushInput {
  const SyncPushInput({required this.operations});

  factory SyncPushInput.fromJson(Map<String, Object?> json) =>
      _$SyncPushInputFromJson(json);

  final List<SyncOperationInput> operations;

  Map<String, Object?> toJson() => _$SyncPushInputToJson(this);
}
