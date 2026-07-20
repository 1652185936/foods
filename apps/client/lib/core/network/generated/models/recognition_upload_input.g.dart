// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recognition_upload_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecognitionUploadInput _$RecognitionUploadInputFromJson(
  Map<String, dynamic> json,
) => RecognitionUploadInput(
  checksumSha256: json['checksumSha256'] as String,
  contentType: RecognitionUploadInputContentType.fromJson(
    json['contentType'] as String,
  ),
  sizeBytes: (json['sizeBytes'] as num).toInt(),
);

Map<String, dynamic> _$RecognitionUploadInputToJson(
  RecognitionUploadInput instance,
) => <String, dynamic>{
  'checksumSha256': instance.checksumSha256,
  'contentType':
      _$RecognitionUploadInputContentTypeEnumMap[instance.contentType]!,
  'sizeBytes': instance.sizeBytes,
};

const _$RecognitionUploadInputContentTypeEnumMap = {
  RecognitionUploadInputContentType.undefined0: 'image/jpeg',
  RecognitionUploadInputContentType.undefined1: 'image/png',
  RecognitionUploadInputContentType.undefined2: 'image/webp',
  RecognitionUploadInputContentType.$unknown: r'$unknown',
};
