import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/meal_log.dart';
import '../recognition/meal_image_picker.dart';
import '../recognition/meal_image_preparer.dart';
import '../recognition/recognition_models.dart';
import '../recognition/recognition_providers.dart';
import 'manual_meal_sheet.dart';

enum _RecognitionFlowExit { manual }

Future<MealDraft?> showRecognitionFlow(
  BuildContext context, {
  required DateTime nowUtc,
  required String timeZoneId,
  required bool isWithinEatingWindow,
}) async {
  final isWide = MediaQuery.sizeOf(context).width >= 600;
  final sheet = RecognitionSheet(
    nowUtc: nowUtc,
    timeZoneId: timeZoneId,
    isWithinEatingWindow: isWithinEatingWindow,
    isDialog: isWide,
  );
  final Object? result;
  if (isWide) {
    result = await showDialog<Object?>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: sheet,
        ),
      ),
    );
  } else {
    result = await showModalBottomSheet<Object?>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => sheet,
    );
  }
  if (result is MealDraft) {
    return result;
  }
  if (result == _RecognitionFlowExit.manual && context.mounted) {
    return showManualMealFlow(
      context,
      nowUtc: nowUtc,
      timeZoneId: timeZoneId,
      isWithinEatingWindow: isWithinEatingWindow,
    );
  }
  return null;
}

enum _RecognitionStage { source, preparing, recognizing, result, failure }

class RecognitionSheet extends ConsumerStatefulWidget {
  const RecognitionSheet({
    required this.nowUtc,
    required this.timeZoneId,
    required this.isWithinEatingWindow,
    this.isDialog = false,
    super.key,
  });

  final DateTime nowUtc;
  final String timeZoneId;
  final bool isWithinEatingWindow;
  final bool isDialog;

  @override
  ConsumerState<RecognitionSheet> createState() => _RecognitionSheetState();
}

class _RecognitionSheetState extends ConsumerState<RecognitionSheet> {
  final _formKey = GlobalKey<FormState>();
  final List<_DishEditor> _editors = <_DishEditor>[];
  _RecognitionStage _stage = _RecognitionStage.source;
  RecognitionProgressStage _progress = RecognitionProgressStage.creatingUpload;
  RecognitionCancellation? _cancellation;
  PreparedMealImage? _image;
  RecognitionJobData? _job;
  RecognitionFailureKind? _failureKind;
  String? _sourceMessage;
  String? _submitError;
  MealType _mealType = MealType.lunch;
  bool _reviewConfirmed = false;
  bool _submitting = false;
  bool _closing = false;

  bool get _busy =>
      _stage == _RecognitionStage.preparing ||
      _stage == _RecognitionStage.recognizing ||
      _submitting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final recovered = ref
          .read(pendingRecoveredMealImageProvider.notifier)
          .take();
      if (recovered != null) {
        setState(() => _sourceMessage = '已恢复上次中断的照片');
        unawaited(_prepareAndRecognize(recovered));
      }
    });
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    _disposeEditors();
    super.dispose();
  }

  Future<void> _pick({required bool camera}) async {
    if (_busy) {
      return;
    }
    final picker = ref.read(mealImagePickerProvider);
    try {
      final picked = camera
          ? await picker.pickFromCamera()
          : await picker.pickFromGallery();
      if (!mounted) {
        return;
      }
      if (picked == null) {
        setState(() => _sourceMessage = '未选择照片，你可以重新选择或手动记录');
        return;
      }
      await _prepareAndRecognize(picked);
    } on MealImagePickerFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failureKind = error.kind == MealImagePickerFailureKind.permissionDenied
            ? RecognitionFailureKind.uploadRejected
            : RecognitionFailureKind.invalidResponse;
        _sourceMessage =
            error.kind == MealImagePickerFailureKind.permissionDenied
            ? '没有照片访问权限，请在系统设置中允许后重试'
            : '暂时无法打开图片选择器，请重试或手动记录';
        _stage = _RecognitionStage.failure;
      });
    }
  }

  Future<void> _prepareAndRecognize(PickedMealImage picked) async {
    setState(() {
      _stage = _RecognitionStage.preparing;
      _sourceMessage = null;
      _failureKind = null;
      _submitError = null;
    });
    try {
      final image = await prepareMealImage(picked);
      if (!mounted) {
        return;
      }
      _image = image;
      await _recognize();
    } on MealImageValidationFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sourceMessage = _validationMessage(error.kind);
        _failureKind = RecognitionFailureKind.uploadRejected;
        _stage = _RecognitionStage.failure;
      });
    }
  }

  Future<void> _recognize() async {
    final image = _image;
    if (image == null) {
      setState(() => _stage = _RecognitionStage.source);
      return;
    }
    _cancellation?.cancel();
    final cancellation = RecognitionCancellation();
    _cancellation = cancellation;
    setState(() {
      _stage = _RecognitionStage.recognizing;
      _progress = RecognitionProgressStage.creatingUpload;
      _failureKind = null;
      _submitError = null;
    });
    try {
      final job = await ref
          .read(mealRecognitionServiceProvider)
          .recognize(
            image,
            cancellation: cancellation,
            onProgress: (progress) {
              if (mounted && identical(_cancellation, cancellation)) {
                setState(() => _progress = progress);
              }
            },
          );
      if (!mounted || !identical(_cancellation, cancellation)) {
        return;
      }
      _setResult(job);
    } on RecognitionFailure catch (error) {
      if (!mounted || error.kind == RecognitionFailureKind.cancelled) {
        return;
      }
      setState(() {
        _failureKind = error.kind;
        _sourceMessage = _recognitionFailureMessage(error.kind);
        _stage = _RecognitionStage.failure;
      });
    }
  }

  void _setResult(RecognitionJobData job) {
    _disposeEditors();
    _job = job;
    _editors.addAll(job.dishes.map(_DishEditor.new));
    setState(() {
      _reviewConfirmed = !job.requiresReview;
      _stage = _RecognitionStage.result;
    });
  }

  Future<void> _confirm() async {
    final job = _job;
    if (job == null || _submitting || !_formKey.currentState!.validate()) {
      return;
    }
    final dishes = _editors.map((editor) => editor.toDish()).toList();
    final changed = _dishesChanged(job.dishes, dishes);
    var finalDishes = dishes;
    if (changed || job.requiresReview) {
      final cancellation = RecognitionCancellation();
      _cancellation = cancellation;
      setState(() {
        _submitting = true;
        _submitError = null;
      });
      try {
        final corrected = await ref
            .read(mealRecognitionServiceProvider)
            .correct(job: job, dishes: dishes, cancellation: cancellation);
        finalDishes = corrected.dishes;
      } on RecognitionFailure catch (error) {
        if (!mounted || error.kind == RecognitionFailureKind.cancelled) {
          return;
        }
        setState(() {
          _submitting = false;
          _submitError = '暂时无法保存你的修正，请重试';
        });
        return;
      }
    }
    if (!mounted) {
      return;
    }
    _dismiss(
      MealDraft(
        type: _mealType,
        source: MealSource.recognition,
        occurredAtUtc: widget.nowUtc.toUtc(),
        timeZoneId: widget.timeZoneId,
        isWithinEatingWindow: widget.isWithinEatingWindow,
        items: finalDishes
            .map(
              (dish) => MealItemDraft(
                name: dish.name,
                servingMilli: dish.servingMilli,
                energyKcal: dish.energyKcal,
                proteinMg: dish.proteinMg,
                carbsMg: dish.carbsMg,
                fatMg: dish.fatMg,
                imageReference: null,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  bool _dishesChanged(
    List<RecognitionDishData> original,
    List<RecognitionDishData> edited,
  ) {
    if (original.length != edited.length) {
      return true;
    }
    for (var index = 0; index < original.length; index++) {
      if (!original[index].sameNutritionAndName(edited[index])) {
        return true;
      }
    }
    return false;
  }

  void _dismiss([Object? result]) {
    if (_closing) {
      return;
    }
    _closing = true;
    _cancellation?.cancel();
    Navigator.of(context).pop(result);
  }

  void _manual() => _dismiss(_RecognitionFlowExit.manual);

  void _chooseAnother() {
    _cancellation?.cancel();
    _image = null;
    _job = null;
    _disposeEditors();
    setState(() {
      _stage = _RecognitionStage.source;
      _failureKind = null;
      _sourceMessage = null;
      _submitError = null;
    });
  }

  void _disposeEditors() {
    for (final editor in _editors) {
      editor.dispose();
    }
    _editors.clear();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        MediaQuery.sizeOf(context).height * (widget.isDialog ? 0.86 : 0.94);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _cancellation?.cancel();
        }
      },
      child: ConstrainedBox(
        key: const Key('recognition-sheet'),
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: AppColors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              widget.isDialog ? 14 : 8,
              20,
              24 + bottomInset,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.isDialog) const _SheetHandle(),
                  _Header(title: _title, onClose: () => _dismiss()),
                  const SizedBox(height: 14),
                  if (_image != null) _ImagePreview(image: _image!),
                  if (_image != null) const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (_stage) {
                      _RecognitionStage.source => _SourceStep(
                        key: const ValueKey('recognition-source'),
                        supportsCamera: ref
                            .watch(mealImagePickerProvider)
                            .supportsCamera,
                        message: _sourceMessage,
                        onCamera: () => _pick(camera: true),
                        onGallery: () => _pick(camera: false),
                        onManual: _manual,
                      ),
                      _RecognitionStage.preparing => const _BusyStep(
                        key: ValueKey('recognition-preparing'),
                        icon: LucideIcons.image,
                        label: '正在检查照片',
                        detail: '只会上传支持的图片内容',
                      ),
                      _RecognitionStage.recognizing => _BusyStep(
                        key: const ValueKey('recognition-running'),
                        icon: LucideIcons.scanLine,
                        label: _progressLabel,
                        detail: '请稍候，你可以随时取消',
                      ),
                      _RecognitionStage.result => _ResultStep(
                        key: const ValueKey('recognition-result'),
                        job: _job!,
                        editors: _editors,
                        mealType: _mealType,
                        reviewConfirmed: _reviewConfirmed,
                        submitting: _submitting,
                        submitError: _submitError,
                        onMealTypeChanged: (value) =>
                            setState(() => _mealType = value),
                        onReviewChanged: (value) =>
                            setState(() => _reviewConfirmed = value),
                        onConfirm: _reviewConfirmed ? _confirm : null,
                        onChooseAnother: _chooseAnother,
                      ),
                      _RecognitionStage.failure => _FailureStep(
                        key: ValueKey(
                          'recognition-failure-${_failureKind?.name}',
                        ),
                        message: _sourceMessage ?? '识别没有完成，请重试',
                        canRetry: _image != null,
                        onRetry: _image == null ? null : _recognize,
                        onChooseAnother: _chooseAnother,
                        onManual: _manual,
                      ),
                    },
                  ),
                  SizedBox(height: _busy ? 12 : 8),
                  TextButton(
                    key: const Key('recognition-cancel'),
                    onPressed: () => _dismiss(),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _title => switch (_stage) {
    _RecognitionStage.source => '拍照识别一餐',
    _RecognitionStage.preparing => '准备照片',
    _RecognitionStage.recognizing => '正在识别',
    _RecognitionStage.result => '核对识别结果',
    _RecognitionStage.failure => '识别未完成',
  };

  String get _progressLabel => switch (_progress) {
    RecognitionProgressStage.creatingUpload => '正在建立安全上传',
    RecognitionProgressStage.uploading => '正在上传照片',
    RecognitionProgressStage.validating => '正在校验照片',
    RecognitionProgressStage.analyzing => '正在分析菜品和营养',
  };

  String _validationMessage(MealImageValidationFailureKind kind) =>
      switch (kind) {
        MealImageValidationFailureKind.empty => '这张照片没有可读取的内容',
        MealImageValidationFailureKind.tooLarge => '照片不能超过 20 MB，请选择较小的图片',
        MealImageValidationFailureKind.unsupportedFormat =>
          '仅支持 JPEG、PNG 或 WebP 图片',
        MealImageValidationFailureKind.changedWhileReading => '照片内容发生了变化，请重新选择',
        MealImageValidationFailureKind.unreadable => '无法读取这张照片，请重新选择',
      };

  String _recognitionFailureMessage(RecognitionFailureKind kind) =>
      switch (kind) {
        RecognitionFailureKind.timedOut => '分析时间比预期更久，请重试或手动记录',
        RecognitionFailureKind.uploadRejected => '照片未通过安全校验，请重新选择',
        RecognitionFailureKind.recognitionFailed => '暂时无法识别这张照片，请换一张或手动记录',
        RecognitionFailureKind.expired => '本次识别已过期，请重新上传',
        RecognitionFailureKind.network => '网络连接不稳定，请检查网络后重试',
        RecognitionFailureKind.invalidResponse => '识别服务返回异常，请稍后重试',
        RecognitionFailureKind.cancelled => '识别已取消',
      };
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      IconButton(
        key: const Key('recognition-close'),
        tooltip: '关闭',
        onPressed: onClose,
        icon: const Icon(LucideIcons.x),
      ),
    ],
  );
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.image});

  final PreparedMealImage image;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: AspectRatio(
      aspectRatio: 1.7,
      child: Image(
        image: ResizeImage(
          MemoryImage(image.bytes),
          width: 1200,
          height: 1200,
          policy: ResizeImagePolicy.fit,
        ),
        key: const Key('recognition-preview'),
        fit: BoxFit.cover,
        semanticLabel: '待识别的餐食照片',
        errorBuilder: (context, _, _) => const ColoredBox(
          color: AppColors.greenSoft,
          child: Center(child: Icon(LucideIcons.imageOff, size: 28)),
        ),
      ),
    ),
  );
}

class _SourceStep extends StatelessWidget {
  const _SourceStep({
    required this.supportsCamera,
    required this.message,
    required this.onCamera,
    required this.onGallery,
    required this.onManual,
    super.key,
  });

  final bool supportsCamera;
  final String? message;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: AppColors.greenSoft,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: const Column(
          children: [
            Icon(LucideIcons.scanLine, size: 34, color: AppColors.primary),
            SizedBox(height: 10),
            Text(
              '让整份餐食保持清晰、光线充足',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      if (message != null) ...[
        const SizedBox(height: 10),
        Text(
          message!,
          key: const Key('recognition-source-message'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
      const SizedBox(height: 16),
      if (supportsCamera) ...[
        FilledButton.icon(
          key: const Key('recognition-camera'),
          onPressed: onCamera,
          icon: const Icon(LucideIcons.camera, size: 19),
          label: const Text('拍摄照片'),
        ),
        const SizedBox(height: 10),
      ],
      OutlinedButton.icon(
        key: const Key('recognition-gallery'),
        onPressed: onGallery,
        icon: const Icon(LucideIcons.images, size: 19),
        label: const Text('从相册选择'),
      ),
      const SizedBox(height: 6),
      TextButton(
        key: const Key('recognition-manual'),
        onPressed: onManual,
        child: const Text('改为手动记录'),
      ),
    ],
  );
}

class _BusyStep extends StatelessWidget {
  const _BusyStep({
    required this.icon,
    required this.label,
    required this.detail,
    super.key,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: label,
    child: Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 12),
        const LinearProgressIndicator(minHeight: 4),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          detail,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _FailureStep extends StatelessWidget {
  const _FailureStep({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onChooseAnother,
    required this.onManual,
    super.key,
  });

  final String message;
  final bool canRetry;
  final VoidCallback? onRetry;
  final VoidCallback onChooseAnother;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(LucideIcons.circleAlert, size: 30, color: AppColors.tomato),
      const SizedBox(height: 10),
      Text(
        message,
        key: const Key('recognition-error-message'),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      if (canRetry)
        FilledButton.icon(
          key: const Key('recognition-retry'),
          onPressed: onRetry,
          icon: const Icon(LucideIcons.refreshCw, size: 19),
          label: const Text('重试识别'),
        ),
      if (canRetry) const SizedBox(height: 10),
      OutlinedButton(
        key: const Key('recognition-choose-another'),
        onPressed: onChooseAnother,
        child: const Text('重新选择照片'),
      ),
      TextButton(
        key: const Key('recognition-manual'),
        onPressed: onManual,
        child: const Text('改为手动记录'),
      ),
    ],
  );
}

class _ResultStep extends StatelessWidget {
  const _ResultStep({
    required this.job,
    required this.editors,
    required this.mealType,
    required this.reviewConfirmed,
    required this.submitting,
    required this.submitError,
    required this.onMealTypeChanged,
    required this.onReviewChanged,
    required this.onConfirm,
    required this.onChooseAnother,
    super.key,
  });

  final RecognitionJobData job;
  final List<_DishEditor> editors;
  final MealType mealType;
  final bool reviewConfirmed;
  final bool submitting;
  final String? submitError;
  final ValueChanged<MealType> onMealTypeChanged;
  final ValueChanged<bool> onReviewChanged;
  final VoidCallback? onConfirm;
  final VoidCallback onChooseAnother;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (job.requiresReview) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.yellowSoft,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.badgeAlert, size: 19),
              SizedBox(width: 8),
              Expanded(child: Text('识别把握较低，请逐项核对后再保存。')),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      DropdownButtonFormField<MealType>(
        key: const Key('recognition-meal-type'),
        initialValue: mealType,
        decoration: const InputDecoration(labelText: '餐次'),
        items: MealType.values
            .map(
              (type) => DropdownMenuItem(value: type, child: Text(type.label)),
            )
            .toList(growable: false),
        onChanged: submitting
            ? null
            : (value) {
                if (value != null) {
                  onMealTypeChanged(value);
                }
              },
      ),
      const SizedBox(height: 14),
      Text(
        '${editors.length} 道菜',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      for (var index = 0; index < editors.length; index++) ...[
        _DishEditorFields(index: index, editor: editors[index]),
        if (index != editors.length - 1) const SizedBox(height: 10),
      ],
      if (job.requiresReview) ...[
        const SizedBox(height: 10),
        CheckboxListTile(
          key: const Key('recognition-review-confirmed'),
          contentPadding: EdgeInsets.zero,
          value: reviewConfirmed,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('我已核对菜品、份量和营养信息'),
          onChanged: submitting
              ? null
              : (value) => onReviewChanged(value ?? false),
        ),
      ],
      if (submitError != null) ...[
        const SizedBox(height: 8),
        Text(
          submitError!,
          key: const Key('recognition-correction-error'),
          style: const TextStyle(color: AppColors.tomato),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('recognition-confirm'),
        onPressed: submitting ? null : onConfirm,
        icon: submitting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(LucideIcons.check, size: 19),
        label: Text(submitting ? '正在保存修正' : '保存这餐'),
      ),
      const SizedBox(height: 8),
      TextButton(
        key: const Key('recognition-choose-another'),
        onPressed: submitting ? null : onChooseAnother,
        child: const Text('换一张照片'),
      ),
    ],
  );
}

class _DishEditorFields extends StatelessWidget {
  const _DishEditorFields({required this.index, required this.editor});

  final int index;
  final _DishEditor editor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '菜品 ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '把握 ${editor.original.confidenceMilli ~/ 10}%',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: Key('recognition-item-$index-name'),
          controller: editor.name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: '菜品名称'),
          validator: (value) {
            final normalized = value?.trim() ?? '';
            if (normalized.isEmpty || normalized.length > 120) {
              return '请输入 1 到 120 个字符';
            }
            return null;
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                key: Key('recognition-item-$index-serving'),
                controller: editor.serving,
                label: '份量',
                suffix: 'g',
                minExclusive: 0,
                max: 10000,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberField(
                key: Key('recognition-item-$index-energy'),
                controller: editor.energy,
                label: '热量',
                suffix: 'kcal',
                min: 0,
                max: 100000,
                integerOnly: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                key: Key('recognition-item-$index-protein'),
                controller: editor.protein,
                label: '蛋白质',
                suffix: 'g',
                min: 0,
                max: 10000,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                key: Key('recognition-item-$index-carbs'),
                controller: editor.carbs,
                label: '碳水',
                suffix: 'g',
                min: 0,
                max: 10000,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                key: Key('recognition-item-$index-fat'),
                controller: editor.fat,
                label: '脂肪',
                suffix: 'g',
                min: 0,
                max: 10000,
              ),
            ),
          ],
        ),
        if (editor.original.alternatives.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(
            '也可能是：${editor.original.alternatives.map((item) => item.name).join('、')}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ],
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.max,
    this.min,
    this.minExclusive,
    this.integerOnly = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final num max;
  final num? min;
  final num? minExclusive;
  final bool integerOnly;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: !integerOnly),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    validator: (value) {
      final parsed = integerOnly
          ? int.tryParse(value ?? '')
          : double.tryParse(value ?? '');
      if (parsed == null ||
          parsed > max ||
          (min != null && parsed < min!) ||
          (minExclusive != null && parsed <= minExclusive!)) {
        return '数值不正确';
      }
      return null;
    },
  );
}

final class _DishEditor {
  _DishEditor(this.original)
    : name = TextEditingController(text: original.name),
      serving = TextEditingController(text: _grams(original.servingMilli)),
      energy = TextEditingController(text: original.energyKcal.toString()),
      protein = TextEditingController(text: _grams(original.proteinMg)),
      carbs = TextEditingController(text: _grams(original.carbsMg)),
      fat = TextEditingController(text: _grams(original.fatMg));

  final RecognitionDishData original;
  final TextEditingController name;
  final TextEditingController serving;
  final TextEditingController energy;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;

  RecognitionDishData toDish() {
    final normalizedName = name.text.trim();
    return RecognitionDishData(
      id: original.id,
      name: normalizedName,
      canonicalFoodId: normalizedName == original.name
          ? original.canonicalFoodId
          : null,
      servingMilli: _milligrams(serving.text),
      energyKcal: int.parse(energy.text),
      proteinMg: _milligrams(protein.text),
      carbsMg: _milligrams(carbs.text),
      fatMg: _milligrams(fat.text),
      confidenceMilli: original.confidenceMilli,
      alternatives: original.alternatives,
      isUserCorrected: true,
    );
  }

  void dispose() {
    name.dispose();
    serving.dispose();
    energy.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
  }

  static int _milligrams(String value) => (double.parse(value) * 1000).round();

  static String _grams(int milli) {
    final grams = milli / 1000;
    return grams == grams.roundToDouble()
        ? grams.toInt().toString()
        : grams.toStringAsFixed(1);
  }
}
