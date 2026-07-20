import 'dart:async';

import 'package:dio/dio.dart';

import 'meal_image_preparer.dart';

enum RecognitionProgressStage {
  creatingUpload,
  uploading,
  validating,
  analyzing,
}

final class RecognitionUploadTicket {
  RecognitionUploadTicket({
    required this.uploadSessionId,
    required this.uploadUri,
    required Map<String, String> uploadHeaders,
  }) : uploadHeaders = Map<String, String>.unmodifiable(uploadHeaders);

  final String uploadSessionId;
  final Uri uploadUri;
  final Map<String, String> uploadHeaders;
}

final class RecognitionDishData {
  const RecognitionDishData({
    required this.id,
    required this.name,
    required this.servingMilli,
    required this.energyKcal,
    required this.proteinMg,
    required this.carbsMg,
    required this.fatMg,
    required this.confidenceMilli,
    this.canonicalFoodId,
    this.alternatives = const <RecognitionAlternativeData>[],
    this.isUserCorrected = false,
  });

  final String id;
  final String name;
  final String? canonicalFoodId;
  final int servingMilli;
  final int energyKcal;
  final int proteinMg;
  final int carbsMg;
  final int fatMg;
  final int confidenceMilli;
  final List<RecognitionAlternativeData> alternatives;
  final bool isUserCorrected;

  bool sameNutritionAndName(RecognitionDishData other) =>
      id == other.id &&
      name == other.name &&
      servingMilli == other.servingMilli &&
      energyKcal == other.energyKcal &&
      proteinMg == other.proteinMg &&
      carbsMg == other.carbsMg &&
      fatMg == other.fatMg;
}

final class RecognitionAlternativeData {
  const RecognitionAlternativeData({
    required this.name,
    required this.confidenceMilli,
  });

  final String name;
  final int confidenceMilli;
}

final class RecognitionJobData {
  RecognitionJobData({
    required this.id,
    required this.status,
    required this.version,
    required List<RecognitionDishData> dishes,
    this.overallConfidenceMilli,
    this.needsReviewReason,
    this.errorCode,
  }) : dishes = List<RecognitionDishData>.unmodifiable(dishes);

  final String id;
  final String status;
  final int version;
  final List<RecognitionDishData> dishes;
  final int? overallConfidenceMilli;
  final String? needsReviewReason;
  final String? errorCode;

  bool get requiresReview =>
      status == 'needs_review' ||
      needsReviewReason != null ||
      (overallConfidenceMilli ?? 1000) < 700 ||
      dishes.any((dish) => dish.confidenceMilli < 600);
}

enum RecognitionFailureKind {
  cancelled,
  timedOut,
  uploadRejected,
  recognitionFailed,
  expired,
  network,
  invalidResponse,
}

final class RecognitionFailure implements Exception {
  const RecognitionFailure(this.kind, {this.code, this.cause});

  final RecognitionFailureKind kind;
  final String? code;
  final Object? cause;
}

final class RecognitionCancellation {
  final Completer<void> _cancelled = Completer<void>();
  final Set<CancelToken> _dioTokens = <CancelToken>{};

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void throwIfCancelled() {
    if (isCancelled) {
      throw const RecognitionFailure(RecognitionFailureKind.cancelled);
    }
  }

  void attach(CancelToken token) {
    throwIfCancelled();
    _dioTokens.add(token);
  }

  void detach(CancelToken token) => _dioTokens.remove(token);

  void cancel() {
    if (_cancelled.isCompleted) {
      return;
    }
    _cancelled.complete();
    for (final token in _dioTokens.toList(growable: false)) {
      token.cancel('recognition_cancelled');
    }
    _dioTokens.clear();
  }

  Future<void> wait(Duration duration) async {
    throwIfCancelled();
    await Future.any<void>(<Future<void>>[
      Future<void>.delayed(duration),
      whenCancelled,
    ]);
    throwIfCancelled();
  }
}

abstract interface class RecognitionRemoteGateway {
  Future<RecognitionUploadTicket> createUpload(PreparedMealImage image);

  Future<void> uploadImage(
    RecognitionUploadTicket ticket,
    PreparedMealImage image,
    RecognitionCancellation cancellation,
  );

  Future<void> completeUpload(String uploadSessionId);

  Future<RecognitionJobData> createRecognition({
    required String uploadSessionId,
    required String idempotencyKey,
  });

  Future<RecognitionJobData> getRecognition(String recognitionId);

  Future<RecognitionJobData> correctRecognition({
    required String recognitionId,
    required int expectedVersion,
    required List<RecognitionDishData> dishes,
  });
}
