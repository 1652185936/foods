import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/generated/models/recognition_correction_input.dart';
import '../../../core/network/generated/models/recognition_correction_item_input.dart';
import '../../../core/network/generated/models/recognition_create_input.dart';
import '../../../core/network/generated/models/recognition_item_response.dart';
import '../../../core/network/generated/models/recognition_response.dart';
import '../../../core/network/generated/models/recognition_upload_input.dart';
import '../../../core/network/generated/models/recognition_upload_input_content_type.dart';
import '../../../core/network/generated/recognition/recognition_api.dart';
import 'meal_image_preparer.dart';
import 'recognition_models.dart';

abstract interface class DirectImageUploader {
  Future<void> put({
    required Uri uri,
    required Map<String, String> headers,
    required List<int> bytes,
    required RecognitionCancellation cancellation,
  });
}

final class DioDirectImageUploader implements DirectImageUploader {
  DioDirectImageUploader({
    Duration connectTimeout = const Duration(seconds: 10),
    Duration sendTimeout = const Duration(minutes: 2),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) : _dio = Dio(
         BaseOptions(
           connectTimeout: connectTimeout,
           sendTimeout: sendTimeout,
           receiveTimeout: receiveTimeout,
         ),
       );

  final Dio _dio;

  @override
  Future<void> put({
    required Uri uri,
    required Map<String, String> headers,
    required List<int> bytes,
    required RecognitionCancellation cancellation,
  }) async {
    _validateUploadUri(uri);
    final Uint8List payload = bytes is Uint8List
        ? bytes
        : Uint8List.fromList(bytes);
    _validateContentLength(headers, payload.length);
    final cancelToken = CancelToken();
    cancellation.attach(cancelToken);
    try {
      await _dio.putUri<void>(
        uri,
        data: payload,
        cancelToken: cancelToken,
        options: Options(
          headers: Map<String, String>.from(headers),
          responseType: ResponseType.plain,
          followRedirects: false,
          maxRedirects: 0,
        ),
      );
    } finally {
      cancellation.detach(cancelToken);
    }
  }

  void close() => _dio.close(force: true);

  void _validateUploadUri(Uri uri) {
    final isLocalHttp = uri.scheme == 'http' && _isLoopback(uri.host);
    if (!uri.isAbsolute ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && !isLocalHttp) ||
        uri.userInfo.isNotEmpty) {
      throw const RecognitionFailure(RecognitionFailureKind.invalidResponse);
    }
  }

  void _validateContentLength(Map<String, String> headers, int byteLength) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != Headers.contentLengthHeader) {
        continue;
      }
      if (int.tryParse(entry.value) != byteLength) {
        throw const RecognitionFailure(RecognitionFailureKind.invalidResponse);
      }
      return;
    }
  }

  bool _isLoopback(String host) {
    if (host.toLowerCase() == 'localhost') {
      return true;
    }
    return InternetAddress.tryParse(host)?.isLoopback ?? false;
  }
}

final class GeneratedRecognitionGateway implements RecognitionRemoteGateway {
  factory GeneratedRecognitionGateway({
    required RecognitionApi api,
    required DirectImageUploader uploader,
  }) => GeneratedRecognitionGateway._(api, uploader);

  const GeneratedRecognitionGateway._(this._api, this._uploader);

  final RecognitionApi _api;
  final DirectImageUploader _uploader;

  @override
  Future<RecognitionUploadTicket> createUpload(PreparedMealImage image) async {
    final response = await _api.createRecognitionUpload(
      body: RecognitionUploadInput(
        checksumSha256: image.checksumSha256,
        contentType: _contentType(image.contentType),
        sizeBytes: image.sizeBytes,
      ),
    );
    final uri = Uri.tryParse(response.uploadUrl);
    if (uri == null || response.uploadSessionId.isEmpty) {
      throw const RecognitionFailure(RecognitionFailureKind.invalidResponse);
    }
    return RecognitionUploadTicket(
      uploadSessionId: response.uploadSessionId,
      uploadUri: uri,
      uploadHeaders: response.uploadHeaders,
    );
  }

  @override
  Future<void> uploadImage(
    RecognitionUploadTicket ticket,
    PreparedMealImage image,
    RecognitionCancellation cancellation,
  ) => _uploader.put(
    uri: ticket.uploadUri,
    headers: ticket.uploadHeaders,
    bytes: image.bytes,
    cancellation: cancellation,
  );

  @override
  Future<void> completeUpload(String uploadSessionId) async {
    await _api.completeRecognitionUpload(uploadSessionId: uploadSessionId);
  }

  @override
  Future<RecognitionJobData> createRecognition({
    required String uploadSessionId,
    required String idempotencyKey,
  }) async {
    final response = await _api.createRecognition(
      idempotencyKey: idempotencyKey,
      body: RecognitionCreateInput(uploadSessionId: uploadSessionId),
    );
    return _job(response);
  }

  @override
  Future<RecognitionJobData> getRecognition(String recognitionId) async {
    final response = await _api.getRecognition(recognitionId: recognitionId);
    return _job(response);
  }

  @override
  Future<RecognitionJobData> correctRecognition({
    required String recognitionId,
    required int expectedVersion,
    required List<RecognitionDishData> dishes,
  }) async {
    final response = await _api.correctRecognition(
      recognitionId: recognitionId,
      body: RecognitionCorrectionInput(
        expectedVersion: expectedVersion,
        items: dishes
            .map(
              (dish) => RecognitionCorrectionItemInput(
                id: dish.id,
                name: dish.name,
                canonicalFoodId: dish.canonicalFoodId,
                servingMilli: dish.servingMilli,
                energyKcal: dish.energyKcal,
                proteinMg: dish.proteinMg,
                carbsMg: dish.carbsMg,
                fatMg: dish.fatMg,
              ),
            )
            .toList(growable: false),
      ),
    );
    return _job(response);
  }

  RecognitionUploadInputContentType _contentType(
    MealImageContentType type,
  ) => switch (type) {
    MealImageContentType.jpeg => RecognitionUploadInputContentType.undefined0,
    MealImageContentType.png => RecognitionUploadInputContentType.undefined1,
    MealImageContentType.webp => RecognitionUploadInputContentType.undefined2,
  };

  RecognitionJobData _job(RecognitionResponse response) => RecognitionJobData(
    id: response.id,
    status: response.status,
    version: response.version,
    overallConfidenceMilli: response.overallConfidenceMilli,
    needsReviewReason: response.needsReviewReason,
    errorCode: response.errorCode,
    dishes: response.items.map(_dish).toList(growable: false),
  );

  RecognitionDishData _dish(RecognitionItemResponse item) =>
      RecognitionDishData(
        id: item.id,
        name: item.name,
        canonicalFoodId: item.canonicalFoodId,
        servingMilli: item.servingMilli,
        energyKcal: item.energyKcal,
        proteinMg: item.proteinMg,
        carbsMg: item.carbsMg,
        fatMg: item.fatMg,
        confidenceMilli: item.confidenceMilli,
        alternatives: item.alternatives
            .map(
              (alternative) => RecognitionAlternativeData(
                name: alternative.name,
                confidenceMilli: alternative.confidenceMilli,
              ),
            )
            .toList(growable: false),
        isUserCorrected: item.isUserCorrected,
      );
}
