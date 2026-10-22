import 'dart:convert';

import 'package:dio/dio.dart';

/// Reads Tolgee Content Delivery files: `<baseUrl>/<languageCode>.json`.
class OtaRemoteDataSource {
  const OtaRemoteDataSource({required this._dio, required this._baseUrl});

  final Dio _dio;
  final String _baseUrl;

  /// Throws [DioException] on transport errors and [FormatException] when the
  /// body is not a JSON object.
  Future<Map<String, String>> fetch(String languageCode) async {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final response = await _dio.get<Object?>(
      '$base/$languageCode.json',
      // The CDN may serve JSON as text/plain or octet-stream; decode ourselves.
      options: Options(responseType: ResponseType.plain),
    );
    return parseTolgeeJson(response.data);
  }
}

/// Flattens a Tolgee JSON export into `key -> message`.
///
/// Handles both flat exports and nested ones (when the Tolgee "structure
/// delimiter" is on), joining nested keys with `.`. Non-string leaves are
/// skipped so a bad value only drops that key, not the whole bundle.
Map<String, String> parseTolgeeJson(Object? body) {
  final decoded = body is String ? jsonDecode(body) : body;
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Tolgee export is not a JSON object');
  }
  final messages = <String, String>{};

  void visit(String prefix, Map<String, dynamic> node) {
    for (final MapEntry(:key, :value) in node.entries) {
      final path = prefix.isEmpty ? key : '$prefix.$key';
      if (value is String) {
        messages[path] = value;
      } else if (value is Map<String, dynamic>) {
        visit(path, value);
      }
    }
  }

  visit('', decoded);
  return messages;
}
