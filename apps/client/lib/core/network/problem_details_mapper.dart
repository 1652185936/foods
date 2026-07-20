import 'package:dio/dio.dart';

import 'generated/models/problem_details.dart';

/// A typed RFC 9457 failure decoded from a non-success API response.
final class ApiProblemException implements Exception {
  const ApiProblemException({
    required this.problem,
    required this.requestUri,
    this.retryAfter,
  });

  final ProblemDetails problem;
  final Uri requestUri;

  /// Preserves either Retry-After delta-seconds or HTTP-date verbatim.
  final String? retryAfter;

  @override
  String toString() =>
      'ApiProblemException(${problem.status}, ${problem.code}, '
      'traceId: ${problem.traceId})';
}

ApiProblemException? mapProblemDetails(DioException error) {
  final response = error.response;
  final data = response?.data;
  if (response == null || data is! Map) {
    return null;
  }

  final json = <String, Object?>{};
  for (final entry in data.entries) {
    if (entry.key is! String) {
      return null;
    }
    json[entry.key as String] = entry.value;
  }

  try {
    return ApiProblemException(
      problem: ProblemDetails.fromJson(json),
      requestUri: error.requestOptions.uri,
      retryAfter: response.headers.value('retry-after'),
    );
  } on Object {
    return null;
  }
}
