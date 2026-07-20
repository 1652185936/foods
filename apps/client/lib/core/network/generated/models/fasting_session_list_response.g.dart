// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fasting_session_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FastingSessionListResponse _$FastingSessionListResponseFromJson(
  Map<String, dynamic> json,
) => FastingSessionListResponse(
  items: (json['items'] as List<dynamic>)
      .map((e) => FastingSessionResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$FastingSessionListResponseToJson(
  FastingSessionListResponse instance,
) => <String, dynamic>{'items': instance.items};
