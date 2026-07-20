import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/features/meals/recognition/generated_recognition_gateway.dart';
import 'package:foods_client/features/meals/recognition/recognition_models.dart';

void main() {
  test(
    'isolated uploader sends exact bytes and signed headers without bearer',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final captured = Completer<_CapturedRequest>();
      server.listen((request) async {
        final bytes = await request.fold<List<int>>(
          <int>[],
          (buffer, chunk) => buffer..addAll(chunk),
        );
        captured.complete(
          _CapturedRequest(
            bytes: bytes,
            contentLength: request.contentLength,
            contentType: request.headers.value(HttpHeaders.contentTypeHeader),
            checksum: request.headers.value('x-amz-checksum-sha256'),
            customHeader: request.headers.value('x-custom-header'),
            authorization: request.headers.value(
              HttpHeaders.authorizationHeader,
            ),
          ),
        );
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
      });
      final uploader = DioDirectImageUploader();
      addTearDown(uploader.close);
      final bytes = <int>[0x89, 0x50, 0x4e, 0x47, 0x01];
      final headers = <String, String>{
        'Content-Type': 'image/png',
        'Content-Length': bytes.length.toString(),
        'x-amz-checksum-sha256': 'signed-checksum',
        'X-Custom-Header': 'preserve this value',
      };

      await uploader.put(
        uri: Uri.parse(
          'http://127.0.0.1:${server.port}/object?signature=secret',
        ),
        headers: headers,
        bytes: bytes,
        cancellation: RecognitionCancellation(),
      );
      final request = await captured.future;

      expect(request.bytes, bytes);
      expect(request.contentLength, bytes.length);
      expect(request.contentType, headers['Content-Type']);
      expect(request.checksum, headers['x-amz-checksum-sha256']);
      expect(request.customHeader, headers['X-Custom-Header']);
      expect(request.authorization, isNull);
    },
  );

  test('uploader never follows a presigned redirect', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final redirectSeen = Completer<void>();
    var redirectRequests = 0;
    var destinationRequests = 0;
    server.listen((request) async {
      await request.drain<void>();
      if (request.uri.path == '/redirect') {
        redirectRequests++;
        if (!redirectSeen.isCompleted) {
          redirectSeen.complete();
        }
        request.response.statusCode = HttpStatus.temporaryRedirect;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          '/destination',
        );
      } else {
        destinationRequests++;
        request.response.statusCode = HttpStatus.ok;
      }
      await request.response.close();
    });
    final uploader = DioDirectImageUploader();
    addTearDown(uploader.close);

    await expectLater(
      uploader.put(
        uri: Uri.parse('http://127.0.0.1:${server.port}/redirect'),
        headers: const <String, String>{'Content-Type': 'image/jpeg'},
        bytes: const <int>[0xff, 0xd8, 0xff],
        cancellation: RecognitionCancellation(),
      ),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          HttpStatus.temporaryRedirect,
        ),
      ),
    );
    await redirectSeen.future;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(redirectRequests, 1);
    expect(destinationRequests, 0);
  });

  test('uploader receive timeout is finite', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestSeen = Completer<void>();
    final releaseResponse = Completer<void>();
    addTearDown(() {
      if (!releaseResponse.isCompleted) {
        releaseResponse.complete();
      }
    });
    server.listen((request) async {
      await request.drain<void>();
      requestSeen.complete();
      await releaseResponse.future;
      await request.response.close();
    });
    final uploader = DioDirectImageUploader(
      connectTimeout: const Duration(seconds: 1),
      sendTimeout: const Duration(seconds: 1),
      receiveTimeout: const Duration(milliseconds: 100),
    );
    addTearDown(uploader.close);

    final operation = uploader.put(
      uri: Uri.parse('http://127.0.0.1:${server.port}/hang'),
      headers: const <String, String>{'Content-Type': 'image/jpeg'},
      bytes: const <int>[0xff, 0xd8, 0xff],
      cancellation: RecognitionCancellation(),
    );
    await requestSeen.future;

    await expectLater(
      operation,
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.receiveTimeout,
        ),
      ),
    );
    releaseResponse.complete();
  });

  test('cancellation aborts an in-flight PUT', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestSeen = Completer<void>();
    final releaseResponse = Completer<void>();
    addTearDown(() {
      if (!releaseResponse.isCompleted) {
        releaseResponse.complete();
      }
    });
    server.listen((request) async {
      await request.drain<void>();
      requestSeen.complete();
      await releaseResponse.future;
      await request.response.close();
    });
    final uploader = DioDirectImageUploader();
    addTearDown(uploader.close);
    final cancellation = RecognitionCancellation();

    final operation = uploader.put(
      uri: Uri.parse('http://127.0.0.1:${server.port}/cancel'),
      headers: const <String, String>{'Content-Type': 'image/jpeg'},
      bytes: const <int>[0xff, 0xd8, 0xff],
      cancellation: cancellation,
    );
    await requestSeen.future;
    cancellation.cancel();

    await expectLater(
      operation,
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    releaseResponse.complete();
  });

  test('HTTP is rejected for lookalike non-loopback hosts', () async {
    final uploader = DioDirectImageUploader();
    addTearDown(uploader.close);

    await expectLater(
      uploader.put(
        uri: Uri.parse('http://127.attacker.example/object'),
        headers: const <String, String>{'Content-Type': 'image/jpeg'},
        bytes: const <int>[0xff, 0xd8, 0xff],
        cancellation: RecognitionCancellation(),
      ),
      throwsA(
        isA<RecognitionFailure>().having(
          (error) => error.kind,
          'kind',
          RecognitionFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('signed Content-Length must match the exact payload', () async {
    final uploader = DioDirectImageUploader();
    addTearDown(uploader.close);

    await expectLater(
      uploader.put(
        uri: Uri.parse('http://127.0.0.1:1/object'),
        headers: const <String, String>{
          'Content-Type': 'image/jpeg',
          'Content-Length': '4',
        },
        bytes: const <int>[0xff, 0xd8, 0xff],
        cancellation: RecognitionCancellation(),
      ),
      throwsA(
        isA<RecognitionFailure>().having(
          (error) => error.kind,
          'kind',
          RecognitionFailureKind.invalidResponse,
        ),
      ),
    );
  });
}

final class _CapturedRequest {
  const _CapturedRequest({
    required this.bytes,
    required this.contentLength,
    required this.contentType,
    required this.checksum,
    required this.customHeader,
    required this.authorization,
  });

  final List<int> bytes;
  final int contentLength;
  final String? contentType;
  final String? checksum;
  final String? customHeader;
  final String? authorization;
}
