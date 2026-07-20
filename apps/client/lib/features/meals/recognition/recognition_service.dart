import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'meal_image_preparer.dart';
import 'recognition_models.dart';

typedef RecognitionProgressCallback =
    void Function(RecognitionProgressStage stage);
typedef RecognitionPollDelay =
    Future<void> Function(
      Duration duration,
      RecognitionCancellation cancellation,
    );

final class MealRecognitionService {
  factory MealRecognitionService({
    required RecognitionRemoteGateway remote,
    Uuid? uuid,
    int maxPollAttempts = 20,
    Duration pollInterval = const Duration(seconds: 1),
    RecognitionPollDelay? delay,
  }) {
    if (maxPollAttempts < 1 || pollInterval < Duration.zero) {
      throw ArgumentError('Polling limits must be finite and non-negative.');
    }
    return MealRecognitionService._(
      remote,
      uuid ?? const Uuid(),
      maxPollAttempts,
      pollInterval,
      delay ?? _defaultDelay,
    );
  }

  MealRecognitionService._(
    this._remote,
    this._uuid,
    this.maxPollAttempts,
    this.pollInterval,
    this._delay,
  );

  final RecognitionRemoteGateway _remote;
  final Uuid _uuid;
  final int maxPollAttempts;
  final Duration pollInterval;
  final RecognitionPollDelay _delay;

  Future<RecognitionJobData> recognize(
    PreparedMealImage image, {
    required RecognitionCancellation cancellation,
    RecognitionProgressCallback? onProgress,
  }) async {
    try {
      cancellation.throwIfCancelled();
      onProgress?.call(RecognitionProgressStage.creatingUpload);
      final ticket = await _remote.createUpload(image);
      cancellation.throwIfCancelled();
      onProgress?.call(RecognitionProgressStage.uploading);
      await _remote.uploadImage(ticket, image, cancellation);
      cancellation.throwIfCancelled();
      onProgress?.call(RecognitionProgressStage.validating);
      await _remote.completeUpload(ticket.uploadSessionId);
      cancellation.throwIfCancelled();
      onProgress?.call(RecognitionProgressStage.analyzing);
      cancellation.throwIfCancelled();
      var job = await _remote.createRecognition(
        uploadSessionId: ticket.uploadSessionId,
        idempotencyKey: _uuid.v4(),
      );
      cancellation.throwIfCancelled();
      for (var attempt = 0; attempt < maxPollAttempts; attempt++) {
        final terminal = _terminalResult(job);
        if (terminal != null) {
          return terminal;
        }
        if (attempt == maxPollAttempts - 1) {
          break;
        }
        await _delay(pollInterval, cancellation);
        job = await _remote.getRecognition(job.id);
        cancellation.throwIfCancelled();
      }
      throw const RecognitionFailure(RecognitionFailureKind.timedOut);
    } on RecognitionFailure {
      rethrow;
    } on DioException catch (error) {
      if (cancellation.isCancelled || error.type == DioExceptionType.cancel) {
        throw const RecognitionFailure(RecognitionFailureKind.cancelled);
      }
      throw RecognitionFailure(RecognitionFailureKind.network, cause: error);
    } catch (error) {
      if (cancellation.isCancelled) {
        throw const RecognitionFailure(RecognitionFailureKind.cancelled);
      }
      throw RecognitionFailure(
        RecognitionFailureKind.invalidResponse,
        cause: error,
      );
    }
  }

  Future<RecognitionJobData> correct({
    required RecognitionJobData job,
    required List<RecognitionDishData> dishes,
    required RecognitionCancellation cancellation,
  }) async {
    try {
      cancellation.throwIfCancelled();
      final corrected = await _remote.correctRecognition(
        recognitionId: job.id,
        expectedVersion: job.version,
        dishes: dishes,
      );
      cancellation.throwIfCancelled();
      if (corrected.status != 'succeeded' || !_hasValidDishes(corrected)) {
        throw const RecognitionFailure(RecognitionFailureKind.invalidResponse);
      }
      return corrected;
    } on RecognitionFailure {
      rethrow;
    } on DioException catch (error) {
      if (cancellation.isCancelled || error.type == DioExceptionType.cancel) {
        throw const RecognitionFailure(RecognitionFailureKind.cancelled);
      }
      throw RecognitionFailure(RecognitionFailureKind.network, cause: error);
    } catch (error) {
      if (cancellation.isCancelled) {
        throw const RecognitionFailure(RecognitionFailureKind.cancelled);
      }
      throw RecognitionFailure(
        RecognitionFailureKind.invalidResponse,
        cause: error,
      );
    }
  }

  RecognitionJobData? _terminalResult(RecognitionJobData job) {
    switch (job.status) {
      case 'succeeded':
      case 'needs_review':
        if (!_hasValidDishes(job)) {
          throw const RecognitionFailure(
            RecognitionFailureKind.invalidResponse,
          );
        }
        return job;
      case 'queued':
      case 'running':
        return null;
      case 'failed':
        throw RecognitionFailure(
          RecognitionFailureKind.recognitionFailed,
          code: job.errorCode,
        );
      case 'expired':
        throw const RecognitionFailure(RecognitionFailureKind.expired);
      default:
        throw const RecognitionFailure(RecognitionFailureKind.invalidResponse);
    }
  }

  bool _hasValidDishes(RecognitionJobData job) {
    if (job.dishes.isEmpty || job.dishes.length > 10) {
      return false;
    }
    return job.dishes.every(
      (dish) =>
          dish.id.isNotEmpty &&
          dish.name.trim().isNotEmpty &&
          dish.name.length <= 120 &&
          dish.servingMilli > 0 &&
          dish.servingMilli <= 10000000 &&
          dish.energyKcal >= 0 &&
          dish.energyKcal <= 100000 &&
          dish.proteinMg >= 0 &&
          dish.proteinMg <= 10000000 &&
          dish.carbsMg >= 0 &&
          dish.carbsMg <= 10000000 &&
          dish.fatMg >= 0 &&
          dish.fatMg <= 10000000 &&
          dish.confidenceMilli >= 0 &&
          dish.confidenceMilli <= 1000,
    );
  }

  static Future<void> _defaultDelay(
    Duration duration,
    RecognitionCancellation cancellation,
  ) => cancellation.wait(duration);
}
