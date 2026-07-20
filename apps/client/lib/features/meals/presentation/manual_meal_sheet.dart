import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../domain/meal_log.dart';

Future<MealDraft?> showManualMealFlow(
  BuildContext context, {
  required DateTime nowUtc,
  required String timeZoneId,
  required bool isWithinEatingWindow,
}) {
  return showModalBottomSheet<MealDraft>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _ManualMealSheet(
      nowUtc: nowUtc,
      timeZoneId: timeZoneId,
      isWithinEatingWindow: isWithinEatingWindow,
    ),
  );
}

class _ManualMealSheet extends StatefulWidget {
  const _ManualMealSheet({
    required this.nowUtc,
    required this.timeZoneId,
    required this.isWithinEatingWindow,
  });

  final DateTime nowUtc;
  final String timeZoneId;
  final bool isWithinEatingWindow;

  @override
  State<_ManualMealSheet> createState() => _ManualMealSheetState();
}

class _ManualMealSheetState extends State<_ManualMealSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _energyController = TextEditingController();
  MealType _type = MealType.lunch;

  @override
  void dispose() {
    _nameController.dispose();
    _energyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      MealDraft(
        type: _type,
        source: MealSource.manual,
        occurredAtUtc: widget.nowUtc.toUtc(),
        timeZoneId: widget.timeZoneId,
        isWithinEatingWindow: widget.isWithinEatingWindow,
        items: <MealItemDraft>[
          MealItemDraft(
            name: _nameController.text.trim(),
            energyKcal: int.parse(_energyController.text),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '手动记一餐',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MealType>(
                key: const Key('manual-meal-type'),
                initialValue: _type,
                decoration: const InputDecoration(labelText: '餐次'),
                items: MealType.values
                    .map(
                      (type) => DropdownMenuItem<MealType>(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('manual-meal-name'),
                controller: _nameController,
                textInputAction: TextInputAction.next,
                maxLength: maxMealItemNameLength,
                decoration: const InputDecoration(
                  labelText: '吃了什么',
                  hintText: '例如：番茄鸡蛋盖饭',
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';
                  if (normalized.isEmpty) {
                    return '请输入菜品名称';
                  }
                  if (normalized.runes.length > maxMealItemNameLength) {
                    return '菜品名称不能超过 120 个字符';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('manual-meal-energy'),
                controller: _energyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '热量',
                  suffixText: 'kcal',
                ),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed < 0 || parsed > 10000) {
                    return '请输入 0 到 10000 的整数';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('manual-meal-save'),
                onPressed: _submit,
                icon: const Icon(LucideIcons.check, size: 19),
                label: const Text('保存记录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
