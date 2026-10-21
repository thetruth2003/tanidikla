import 'dart:async';
import 'dart:convert';

import 'package:ankara_proje/core/config/app_environment.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  final int statusCode;
  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      baseUrl = (baseUrl ?? AppEnvironment.apiBaseUrl).replaceFirst(
        RegExp(r'/$'),
        '',
      );

  final http.Client _httpClient;
  final String baseUrl;
  static const Duration _defaultTimeout = Duration(seconds: 15);
  static const Duration _uploadTimeout = Duration(seconds: 45);
  String? bearerToken;
  Future<bool> Function()? onUnauthorized;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?> query = const {},
    Duration? timeout,
  }) => request('GET', path, query: query, timeout: timeout);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> body = const {},
    Duration? timeout,
  }) => request('POST', path, body: body, timeout: timeout);

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, Object?> body = const {},
    Duration? timeout,
  }) => request('PUT', path, body: body, timeout: timeout);

  Future<Map<String, dynamic>> delete(String path, {Duration? timeout}) =>
      request('DELETE', path, timeout: timeout);

  Future<Map<String, dynamic>> uploadImage(
    String path, {
    required List<int> bytes,
    required String filename,
    required Map<String, String> fields,
    bool retryOnUnauthorized = true,
    Duration timeout = _uploadTimeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final multipart = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['X-Client-Type'] = 'mobile'
      ..headers['X-Device-Name'] = 'Yakindaki-Hizmetler-Mobile'
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    final token = bearerToken;
    if (token != null && token.isNotEmpty) {
      multipart.headers['Authorization'] = 'Bearer $token';
    }
    final response = await _send(multipart, timeout: timeout);
    Map<String, dynamic> envelope;
    try {
      envelope = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    } catch (_) {
      throw ApiException(
        statusCode: response.statusCode,
        code: 'invalid_api_response',
        message: 'Sunucudan geçersiz bir cevap geldi.',
      );
    }
    if (response.statusCode == 401 &&
        retryOnUnauthorized &&
        onUnauthorized != null &&
        await onUnauthorized!()) {
      return uploadImage(
        path,
        bytes: bytes,
        filename: filename,
        fields: fields,
        retryOnUnauthorized: false,
        timeout: timeout,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = envelope['error'] is Map
          ? Map<String, dynamic>.from(envelope['error'] as Map)
          : const <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        code: error['code']?.toString() ?? 'upload_failed',
        message: error['message']?.toString() ?? 'Görsel yüklenemedi.',
        details: error['details'],
      );
    }
    final data = envelope['data'];
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?>? body,
    bool retryOnUnauthorized = true,
    Duration? timeout,
  }) async {
    final queryParameters = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final httpRequest = http.Request(method, uri)
      ..headers['Accept'] = 'application/json'
      ..headers['X-Client-Type'] = 'mobile'
      ..headers['X-Device-Name'] = 'Yakindaki-Hizmetler-Mobile';
    final token = bearerToken;
    if (token != null && token.isNotEmpty) {
      httpRequest.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      httpRequest.headers['Content-Type'] = 'application/json; charset=utf-8';
      httpRequest.body = jsonEncode(body);
    }

    final response = await _send(
      httpRequest,
      timeout: timeout ?? _defaultTimeout,
    );
    Map<String, dynamic> envelope;
    try {
      envelope = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    } catch (_) {
      throw ApiException(
        statusCode: response.statusCode,
        code: 'invalid_api_response',
        message: 'Sunucudan geçersiz bir cevap geldi.',
      );
    }

    if (response.statusCode == 401 &&
        retryOnUnauthorized &&
        path != '/auth/refresh' &&
        onUnauthorized != null &&
        await onUnauthorized!()) {
      return request(
        method,
        path,
        query: query,
        body: body,
        retryOnUnauthorized: false,
        timeout: timeout,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = envelope['error'] is Map
          ? Map<String, dynamic>.from(envelope['error'] as Map)
          : const <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        code: error['code']?.toString() ?? 'request_failed',
        message: error['message']?.toString() ?? 'Sunucu isteği tamamlanamadı.',
        details: error['details'],
      );
    }

    final data = envelope['data'];
    return data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{'value': data};
  }

  Future<http.Response> _send(
    http.BaseRequest request, {
    required Duration timeout,
  }) async {
    try {
      return await (() async {
        final streamed = await _httpClient.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        code: 'request_timeout',
        message: 'Sunucu yanıtı gecikti. Lütfen tekrar deneyin.',
      );
    }
  }
}

final apiClient = ApiClient();
