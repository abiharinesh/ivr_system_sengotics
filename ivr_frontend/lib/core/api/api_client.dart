import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/core/storage/secure_storage.dart';
import 'api_exceptions.dart';

class CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  CacheEntry(this.data, this.timestamp);
}

class ApiClient {
  late final Dio _dio;
  static ApiClient? _instance;
  final Map<String, CacheEntry> _cache = {};

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  String _getCacheKey(String path, Map<String, dynamic>? queryParams) {
    if (queryParams == null || queryParams.isEmpty) {
      return path;
    }
    final sortedKeys = queryParams.keys.toList()..sort();
    final queryStr = sortedKeys.map((k) => '$k=${queryParams[k]}').join('&');
    return '$path?$queryStr';
  }

  /// Expose synchronous cache retrieval for fast screen builds
  dynamic getCached(String path, {Map<String, dynamic>? queryParams, Duration maxAge = const Duration(minutes: 5)}) {
    final key = _getCacheKey(path, queryParams);
    final entry = _cache[key];
    if (entry != null && DateTime.now().difference(entry.timestamp) < maxAge) {
      return entry.data;
    }
    return null;
  }

  /// Manually clear cache (e.g. on mutation or manual refresh)
  void clearCache() {
    _cache.clear();
  }

  // GET
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams, bool forceRefresh = false}) async {
    final key = _getCacheKey(path, queryParams);
    if (!forceRefresh && _cache.containsKey(key)) {
      final entry = _cache[key]!;
      if (DateTime.now().difference(entry.timestamp) < const Duration(minutes: 5)) {
        return entry.data;
      }
    }

    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _dio.get(path, queryParameters: queryParams);
        _cache[key] = CacheEntry(response.data, DateTime.now());
        return response.data;
      } on DioException catch (e) {
        final shouldRetry = _shouldRetry(e) && attempt < maxAttempts;
        if (!shouldRetry) {
          throw _handleError(e);
        }
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
    throw ApiException('Failed to load data');
  }

  // POST
  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      clearCache();
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST expecting HTML body (template preview).
  Future<String> postHtml(String path, {dynamic data}) async {
    try {
      clearCache();
      final response = await _dio.post<String>(
        path,
        data: data,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return response.data ?? '';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PUT
  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      clearCache();
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PATCH
  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      clearCache();
      final response = await _dio.patch(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Binary GET (ZIP downloads).
  Future<Uint8List> getBytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final data = response.data;
      if (data == null) throw ApiException('Empty response body');
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Binary GET that also surfaces the response's filename (from
  /// `Content-Disposition: attachment; filename="..."`) and content type so
  /// downloads can save with a sensible name across web/mobile.
  Future<DownloadedFile> getDownload(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final data = response.data;
      if (data == null) throw ApiException('Empty response body');
      final headers = response.headers;
      final disposition = headers.value('content-disposition');
      final contentType = headers.value('content-type');
      return DownloadedFile(
        bytes: Uint8List.fromList(data),
        filename: _filenameFromDisposition(disposition) ?? _filenameFromPath(path),
        contentType: contentType,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static String? _filenameFromDisposition(String? disposition) {
    if (disposition == null || disposition.isEmpty) return null;
    // RFC 5987 form: filename*=UTF-8''my%20file.pdf
    final star = RegExp(r"filename\*\s*=\s*[^']*'[^']*'([^;]+)", caseSensitive: false)
        .firstMatch(disposition);
    if (star != null) {
      try {
        return Uri.decodeComponent(star.group(1)!.trim());
      } catch (_) {}
    }
    // Legacy form: filename="something.pdf" or filename=something.pdf
    final plain = RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false)
        .firstMatch(disposition);
    return plain?.group(1)?.trim();
  }

  static String? _filenameFromPath(String path) {
    final clean = path.split('?').first;
    final segs = clean.split('/').where((s) => s.isNotEmpty).toList();
    return segs.isEmpty ? null : segs.last;
  }

  /// Multipart POST (e.g. image + geotag fields).
  Future<dynamic> postMultipart(String path, FormData formData) async {
    try {
      clearCache();
      final response = await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE
  Future<dynamic> delete(String path) async {
    try {
      clearCache();
      final response = await _dio.delete(path);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ApiException _handleError(DioException e) {
    final statusCode = e.response?.statusCode;
    dynamic data = e.response?.data;
    String message = 'Something went wrong';

    if (data is List<int>) {
      try {
        final decodedString = utf8.decode(data);
        try {
          data = jsonDecode(decodedString);
        } catch (_) {
          data = decodedString;
        }
      } catch (_) {}
    }

    if (data is Map<String, dynamic>) {
      message = data['message']?.toString() ?? message;
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    switch (statusCode) {
      case 400:
        return ValidationException(message);
      case 401:
        return UnauthorizedException(message);
      case 403:
        return ForbiddenException(message);
      case 404:
        return NotFoundException(message);
      case 429:
        return ApiException(
          'Too many requests. Please try again later.',
          statusCode: 429,
        );
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return ApiException(
            'Connection timed out. Please check your network.',
            statusCode: 0,
          );
        }
        if (e.type == DioExceptionType.connectionError) {
          return ApiException(
            'Cannot connect to server. Is it running?',
            statusCode: 0,
          );
        }
        return ServerException(message);
    }
  }

  bool _shouldRetry(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode != null && statusCode >= 500) {
      return true;
    }
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }
}

/// Container for a downloaded file produced by [ApiClient.getDownload].
class DownloadedFile {
  final Uint8List bytes;
  final String? filename;
  final String? contentType;
  const DownloadedFile({
    required this.bytes,
    this.filename,
    this.contentType,
  });
}
