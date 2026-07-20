// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProblemDetails _$ProblemDetailsFromJson(Map<String, dynamic> json) =>
    ProblemDetails(
      code: json['code'] as String,
      status: (json['status'] as num).toInt(),
      title: json['title'] as String,
      traceId: json['traceId'] as String,
      type: json['type'] as String,
      detail: json['detail'] as String?,
      fieldErrors: (json['fieldErrors'] as List<dynamic>?)
          ?.map((e) => FieldProblem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProblemDetailsToJson(ProblemDetails instance) =>
    <String, dynamic>{
      'code': instance.code,
      'detail': instance.detail,
      'fieldErrors': instance.fieldErrors,
      'status': instance.status,
      'title': instance.title,
      'traceId': instance.traceId,
      'type': instance.type,
    };
