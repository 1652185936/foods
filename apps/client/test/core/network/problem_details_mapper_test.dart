import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/network/problem_details_mapper.dart';

void main() {
  test('maps Problem Details and preserves Retry-After', () {
    final request = RequestOptions(
      baseUrl: 'https://api.example.test',
      path: '/api/v1/auth/otp/challenges',
    );
    final error = DioException.badResponse(
      statusCode: 429,
      requestOptions: request,
      response: Response<Object?>(
        requestOptions: request,
        statusCode: 429,
        headers: Headers.fromMap({
          'content-type': ['application/problem+json'],
          'retry-after': ['30'],
        }),
        data: {
          'type': 'https://api.ordin.test/problems/rate-limited',
          'title': 'Too many requests',
          'status': 429,
          'code': 'otp_rate_limited',
          'detail': 'Try again later.',
          'traceId': 'trace-123',
          'fieldErrors': [
            {'field': 'phoneNumber', 'code': 'invalid', 'message': 'Invalid'},
          ],
        },
      ),
    );

    final result = mapProblemDetails(error);

    expect(result, isNotNull);
    expect(result!.problem.code, 'otp_rate_limited');
    expect(result.problem.fieldErrors!.single.field, 'phoneNumber');
    expect(result.retryAfter, '30');
    expect(
      result.requestUri.toString(),
      contains('/api/v1/auth/otp/challenges'),
    );
  });

  test('returns null for a non-conforming error body', () {
    final request = RequestOptions(path: '/broken');
    final error = DioException.badResponse(
      statusCode: 500,
      requestOptions: request,
      response: Response<Object?>(
        requestOptions: request,
        statusCode: 500,
        data: {'message': 'not Problem Details'},
      ),
    );

    expect(mapProblemDetails(error), isNull);
  });
}
