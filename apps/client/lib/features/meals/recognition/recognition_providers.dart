import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/db/database_provider.dart';
import 'generated_recognition_gateway.dart';
import 'meal_image_picker.dart';
import 'recognition_models.dart';
import 'recognition_service.dart';

final mealImagePickerProvider = Provider<MealImagePicker>(
  (ref) => ImagePickerMealImagePicker(),
);

final directImageUploaderProvider = Provider<DirectImageUploader>((ref) {
  final uploader = DioDirectImageUploader();
  ref.onDispose(uploader.close);
  return uploader;
});

final recognitionRemoteGatewayProvider = Provider<RecognitionRemoteGateway>(
  (ref) => GeneratedRecognitionGateway(
    api: ref.watch(ordinApiClientsProvider).recognition,
    uploader: ref.watch(directImageUploaderProvider),
  ),
  dependencies: [ordinApiClientsProvider, directImageUploaderProvider],
);

final mealRecognitionServiceProvider = Provider<MealRecognitionService>(
  (ref) => MealRecognitionService(
    remote: ref.watch(recognitionRemoteGatewayProvider),
  ),
  dependencies: [recognitionRemoteGatewayProvider],
);

final pendingRecoveredMealImageProvider =
    NotifierProvider<PendingRecoveredMealImageController, PickedMealImage?>(
      PendingRecoveredMealImageController.new,
      dependencies: [accountScopeProvider],
    );

class PendingRecoveredMealImageController extends Notifier<PickedMealImage?> {
  @override
  PickedMealImage? build() {
    ref.watch(accountScopeProvider);
    return null;
  }

  void offer(PickedMealImage image) => state = image;

  PickedMealImage? take() {
    final image = state;
    state = null;
    return image;
  }
}

final lostImageRecoveryProvider = Provider<LostImageRecovery>(
  (ref) {
    ref.watch(accountScopeProvider);
    final recovery = LostImageRecovery(
      picker: ref.watch(mealImagePickerProvider),
      onRecovered: ref.read(pendingRecoveredMealImageProvider.notifier).offer,
    );
    ref.onDispose(recovery.dispose);
    return recovery;
  },
  dependencies: [
    accountScopeProvider,
    mealImagePickerProvider,
    pendingRecoveredMealImageProvider,
  ],
);

final class LostImageRecovery {
  factory LostImageRecovery({
    required MealImagePicker picker,
    required void Function(PickedMealImage image) onRecovered,
  }) => LostImageRecovery._(picker, onRecovered);

  LostImageRecovery._(this._picker, this._onRecovered);

  final MealImagePicker _picker;
  final void Function(PickedMealImage image) _onRecovered;
  Future<void>? _inFlight;
  bool _disposed = false;

  Future<void> recover() => _inFlight ??= _recoverOnce();

  void dispose() => _disposed = true;

  Future<void> _recoverOnce() async {
    try {
      final image = await _picker.recoverLostImage();
      if (!_disposed && image != null) {
        _onRecovered(image);
      }
    } on MealImagePickerFailure {
      // Recovery stays non-blocking; the normal picker remains available.
    }
  }
}
