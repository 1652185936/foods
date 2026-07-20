import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/auth_controller.dart';
import 'package:foods_client/features/auth/presentation/auth_session_gate.dart';
import 'package:foods_client/features/meals/recognition/meal_image_picker.dart';
import 'package:foods_client/features/meals/recognition/recognition_lost_data_recovery_host.dart';
import 'package:foods_client/features/meals/recognition/recognition_providers.dart';

import '../../support/auth_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 21, 4);

  testWidgets(
    'a recovered image cannot cross account A logout into account B',
    (tester) async {
      final picker = _RecoveryPicker(<Future<PickedMealImage?>>[
        Future<PickedMealImage?>.value(_pickedImage('account-a.jpg')),
        Future<PickedMealImage?>.value(),
      ]);
      var auth = AuthAuthenticated(
        session: authTestSession(authTestUserA, now),
        scopeGeneration: 1,
      );
      AuthAuthenticated? visibleAuth = auth;
      late StateSetter rebuild;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [mealImagePickerProvider.overrideWithValue(picker)],
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return _recoveryAccountApp(visibleAuth);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pending:account-a.jpg'), findsOneWidget);

      rebuild(() => visibleAuth = null);
      await tester.pump();
      expect(find.text('signed-out'), findsOneWidget);

      auth = AuthAuthenticated(
        session: authTestSession(authTestUserB, now),
        scopeGeneration: 2,
      );
      rebuild(() => visibleAuth = auth);
      await tester.pumpAndSettle();

      expect(find.text('pending:none'), findsOneWidget);
      await tester.tap(find.byKey(const Key('take-recovered-image')));
      await tester.pump();
      expect(find.text('taken:none'), findsOneWidget);
      expect(picker.recoverCalls, 2);
    },
  );

  testWidgets('late recovery completion is dropped after account disposal', (
    tester,
  ) async {
    final accountARecovery = Completer<PickedMealImage?>();
    final picker = _RecoveryPicker(<Future<PickedMealImage?>>[
      accountARecovery.future,
      Future<PickedMealImage?>.value(),
    ]);
    AuthAuthenticated? visibleAuth = AuthAuthenticated(
      session: authTestSession(authTestUserA, now),
      scopeGeneration: 1,
    );
    late StateSetter rebuild;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mealImagePickerProvider.overrideWithValue(picker)],
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _recoveryAccountApp(visibleAuth);
          },
        ),
      ),
    );
    await tester.pump();
    expect(picker.recoverCalls, 1);

    rebuild(() => visibleAuth = null);
    await tester.pump();
    rebuild(
      () => visibleAuth = AuthAuthenticated(
        session: authTestSession(authTestUserB, now),
        scopeGeneration: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(picker.recoverCalls, 2);

    accountARecovery.complete(_pickedImage('late-account-a.jpg'));
    await tester.pumpAndSettle();

    expect(find.text('pending:none'), findsOneWidget);
    await tester.tap(find.byKey(const Key('take-recovered-image')));
    await tester.pump();
    expect(find.text('taken:none'), findsOneWidget);
  });
}

Widget _recoveryAccountApp(AuthAuthenticated? auth) {
  if (auth == null) {
    return const MaterialApp(home: Scaffold(body: Text('signed-out')));
  }
  return AuthenticatedAccountScope(
    key: ValueKey('account:${auth.session.userId}:${auth.scopeGeneration}'),
    auth: auth,
    child: const RecognitionLostDataRecoveryHost(
      child: MaterialApp(home: _RecoveryProbe()),
    ),
  );
}

class _RecoveryProbe extends ConsumerStatefulWidget {
  const _RecoveryProbe();

  @override
  ConsumerState<_RecoveryProbe> createState() => _RecoveryProbeState();
}

class _RecoveryProbeState extends ConsumerState<_RecoveryProbe> {
  String _takenName = 'not-taken';

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingRecoveredMealImageProvider);
    return Scaffold(
      body: Column(
        children: [
          Text('pending:${pending?.file.name ?? 'none'}'),
          Text('taken:$_takenName'),
          FilledButton(
            key: const Key('take-recovered-image'),
            onPressed: () {
              final image = ref
                  .read(pendingRecoveredMealImageProvider.notifier)
                  .take();
              setState(() => _takenName = image?.file.name ?? 'none');
            },
            child: const Text('take'),
          ),
        ],
      ),
    );
  }
}

final class _RecoveryPicker implements MealImagePicker {
  _RecoveryPicker(List<Future<PickedMealImage?>> recoveries)
    : _recoveries = List<Future<PickedMealImage?>>.from(recoveries);

  final List<Future<PickedMealImage?>> _recoveries;
  int recoverCalls = 0;

  @override
  bool get supportsCamera => false;

  @override
  Future<PickedMealImage?> pickFromCamera() async => null;

  @override
  Future<PickedMealImage?> pickFromGallery() async => null;

  @override
  Future<PickedMealImage?> recoverLostImage() {
    recoverCalls++;
    return _recoveries.removeAt(0);
  }
}

final class _NamedMealImageFile implements MealImageFile {
  const _NamedMealImageFile(this.name);

  @override
  final String name;

  @override
  Future<int> length() async => 3;

  @override
  Stream<List<int>> openRead(int start, int end) =>
      Stream<List<int>>.value(const <int>[0xff, 0xd8, 0xff]);
}

PickedMealImage _pickedImage(String name) => PickedMealImage(
  file: _NamedMealImageFile(name),
  origin: MealImageOrigin.recovered,
);
