import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/network/generated/models/account_data_export_response.dart';
import 'package:foods_client/core/network/generated/models/user_response.dart';
import 'package:foods_client/features/profile/data/account_export_file_sharer.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'ordin-account-export-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'shares UTF-8 JSON without putting the user id in the file name',
    () async {
      final gateway = _InspectingShareGateway();
      final sharer = NativeAccountExportFileSharer(
        loadTemporaryDirectory: () async => temporaryDirectory,
        shareGateway: gateway,
        clock: () => DateTime.utc(2026, 7, 21, 3, 4, 5),
      );

      await sharer.share(_exportFixture());

      expect(gateway.fileName, 'ordin-account-data-20260721-030405Z.json');
      expect(gateway.fileName, isNot(contains(_userId)));
      final decoded = jsonDecode(gateway.contents) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 1);
      expect(decoded['exportedAt'], '2026-07-21T03:00:00.000Z');
      expect((decoded['user'] as Map<String, dynamic>)['nickname'], '测试用户');
      expect(utf8.decode(utf8.encode(gateway.contents)), gateway.contents);
      expect(await File(gateway.path).exists(), isFalse);
      expect(await temporaryDirectory.list().toList(), isEmpty);
    },
  );

  test('deletes the temporary JSON even when native sharing fails', () async {
    final gateway = _InspectingShareGateway(fail: true);
    final sharer = NativeAccountExportFileSharer(
      loadTemporaryDirectory: () async => temporaryDirectory,
      shareGateway: gateway,
    );

    await expectLater(sharer.share(_exportFixture()), throwsStateError);

    expect(gateway.path, isNotEmpty);
    expect(await File(gateway.path).exists(), isFalse);
    expect(await temporaryDirectory.list().toList(), isEmpty);
  });
}

const _userId = '11111111-1111-4111-8111-111111111111';

AccountDataExportResponse _exportFixture() {
  return AccountDataExportResponse(
    exportedAt: DateTime.utc(2026, 7, 21, 3),
    fastingSessions: const [],
    healthProfile: null,
    meals: const [],
    preferences: null,
    recognitions: const [],
    user: UserResponse(
      createdAt: DateTime.utc(2026, 7, 1),
      id: _userId,
      nickname: '测试用户',
      status: 'active',
      updatedAt: DateTime.utc(2026, 7, 20),
      version: 2,
    ),
  );
}

final class _InspectingShareGateway implements NativeFileShareGateway {
  _InspectingShareGateway({this.fail = false});

  final bool fail;
  String path = '';
  String fileName = '';
  String contents = '';

  @override
  Future<void> shareJsonFile({
    required String path,
    required String fileName,
    Rect? sharePositionOrigin,
  }) async {
    this.path = path;
    this.fileName = fileName;
    final file = File(path);
    expect(await file.exists(), isTrue);
    contents = await file.readAsString(encoding: utf8);
    if (fail) {
      throw StateError('share failed');
    }
  }
}
