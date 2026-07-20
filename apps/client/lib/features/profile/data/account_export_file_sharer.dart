import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/generated/models/account_data_export_response.dart';

typedef TemporaryDirectoryLoader = Future<Directory> Function();

abstract interface class AccountExportFileSharer {
  Future<void> share(
    AccountDataExportResponse export, {
    Rect? sharePositionOrigin,
  });
}

abstract interface class NativeFileShareGateway {
  Future<void> shareJsonFile({
    required String path,
    required String fileName,
    Rect? sharePositionOrigin,
  });
}

final class SharePlusFileShareGateway implements NativeFileShareGateway {
  const SharePlusFileShareGateway();

  @override
  Future<void> shareJsonFile({
    required String path,
    required String fileName,
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile(path, name: fileName, mimeType: 'application/json'),
        ],
        fileNameOverrides: <String>[fileName],
        title: '好好吃饭账号数据',
        subject: '好好吃饭账号数据',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

final class NativeAccountExportFileSharer implements AccountExportFileSharer {
  NativeAccountExportFileSharer({
    TemporaryDirectoryLoader? loadTemporaryDirectory,
    NativeFileShareGateway? shareGateway,
    DateTime Function()? clock,
  }) : _loadTemporaryDirectory =
           loadTemporaryDirectory ?? getTemporaryDirectory,
       _shareGateway = shareGateway ?? const SharePlusFileShareGateway(),
       _clock = clock ?? DateTime.now;

  static const _encoder = JsonEncoder.withIndent('  ');

  final TemporaryDirectoryLoader _loadTemporaryDirectory;
  final NativeFileShareGateway _shareGateway;
  final DateTime Function() _clock;

  @override
  Future<void> share(
    AccountDataExportResponse export, {
    Rect? sharePositionOrigin,
  }) async {
    final directory = await _loadTemporaryDirectory();
    final fileName = _fileName(_clock().toUtc());
    final file = File(path.join(directory.path, fileName));

    try {
      final bytes = utf8.encode(_encoder.convert(export.toJson()));
      await file.writeAsBytes(bytes, flush: true);
      await _shareGateway.shareJsonFile(
        path: file.path,
        fileName: fileName,
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static String _fileName(DateTime value) {
    String twoDigits(int part) => part.toString().padLeft(2, '0');
    final stamp =
        '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}'
        '-${twoDigits(value.hour)}${twoDigits(value.minute)}'
        '${twoDigits(value.second)}Z';
    return 'ordin-account-data-$stamp.json';
  }
}
