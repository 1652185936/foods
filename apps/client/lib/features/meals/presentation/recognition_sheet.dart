import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';

Future<bool?> showRecognitionFlow(BuildContext context) {
  final isWide = MediaQuery.sizeOf(context).width >= 600;
  if (isWide) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: const RecognitionSheet(isDialog: true),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => const RecognitionSheet(),
  );
}

enum _RecognitionStage { scanning, result }

class RecognitionSheet extends StatefulWidget {
  const RecognitionSheet({super.key, this.isDialog = false});

  final bool isDialog;

  @override
  State<RecognitionSheet> createState() => _RecognitionSheetState();
}

class _RecognitionSheetState extends State<RecognitionSheet> {
  Timer? _scanTimer;
  _RecognitionStage _stage = _RecognitionStage.scanning;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _scanTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() => _stage = _RecognitionStage.result);
      }
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  void _dismiss([bool? saved]) {
    if (_closing) {
      return;
    }
    _closing = true;
    _scanTimer?.cancel();
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        MediaQuery.sizeOf(context).height * (widget.isDialog ? 0.82 : 0.9);

    return ConstrainedBox(
      key: const Key('recognition-sheet'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: AppColors.surface,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, widget.isDialog ? 14 : 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isDialog)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _stage == _RecognitionStage.scanning ? '正在识别' : '确认这餐',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('recognition-close'),
                    tooltip: '关闭',
                    onPressed: _dismiss,
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 1.7,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/chicken-salad.webp',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        semanticLabel: '待识别的鸡胸牛油果沙拉',
                      ),
                      if (_stage == _RecognitionStage.scanning) ...[
                        ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
                        const Center(
                          child: SizedBox.square(
                            dimension: 42,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _stage == _RecognitionStage.scanning
                      ? const _ScanningContent(key: ValueKey('scanning'))
                      : const _RecognitionResult(key: ValueKey('result')),
                ),
              ),
              const SizedBox(height: 20),
              if (_stage == _RecognitionStage.result) ...[
                FilledButton.icon(
                  key: const Key('recognition-confirm'),
                  onPressed: () => _dismiss(true),
                  icon: const Icon(LucideIcons.check, size: 19),
                  label: const Text('记为午餐'),
                ),
                const SizedBox(height: 10),
              ],
              TextButton(
                key: const Key('recognition-cancel'),
                onPressed: _dismiss,
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanningContent extends StatelessWidget {
  const _ScanningContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(LucideIcons.scanLine, color: AppColors.green, size: 26),
        SizedBox(height: 10),
        Text(
          '正在分析菜品和份量',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 5),
        Text(
          '通常几秒内完成',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _RecognitionResult extends StatelessWidget {
  const _RecognitionResult({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('鸡胸牛油果沙拉', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        const Text(
          '估算 420 kcal · 1 份',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: _NutrientResult(
                label: '蛋白质',
                value: '38 g',
                color: AppColors.blueSoft,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _NutrientResult(
                label: '碳水',
                value: '29 g',
                color: AppColors.yellowSoft,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _NutrientResult(
                label: '脂肪',
                value: '17 g',
                color: AppColors.tomatoSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NutrientResult extends StatelessWidget {
  const _NutrientResult({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
