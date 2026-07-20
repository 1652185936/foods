import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recognition_providers.dart';

class RecognitionLostDataRecoveryHost extends ConsumerStatefulWidget {
  const RecognitionLostDataRecoveryHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RecognitionLostDataRecoveryHost> createState() =>
      _RecognitionLostDataRecoveryHostState();
}

class _RecognitionLostDataRecoveryHostState
    extends ConsumerState<RecognitionLostDataRecoveryHost> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(lostImageRecoveryProvider).recover());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
