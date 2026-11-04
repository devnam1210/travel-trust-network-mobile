import 'package:dio/dio.dart';

import '../config/app_config.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.isUncertain = false,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final bool isUncertain;

  bool get isUnauthorized => statusCode == 401;
}

class ApiService {
  ApiService({Dio? dio, String baseUrl = AppConfig.apiBaseUrl})
    : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl.replaceFirst(RegExp(r'/+$'), ''),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      headers: {'Accept': Headers.jsonContentType},
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (accessToken != null && !options.path.startsWith('/auth/')) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  String? accessToken;
  Future<void> Function()? onVisitUnauthorized;

  Future<Map<String, dynamic>> get(String path) async =>
      _object(await _request(path));

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async => _object(await _request(path, method: 'POST', data: data));

  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, dynamic>? data,
  ]) async => _object(await _request(path, method: 'PUT', data: data));

  Future<Map<String, dynamic>> upload(String path, String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split(RegExp(r'[\\/]')).last,
      ),
    });
    return _object(await _request(path, method: 'POST', data: form));
  }

  Future<List<dynamic>> getList(String path) async {
    final data = await _request(path);
    if (data is! List<dynamic>) {
      throw const ApiException('Phản hồi từ máy chủ không phải danh sách.');
    }
    return data;
  }

  Map<String, dynamic> _object(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Phản hồi từ máy chủ thiếu dữ liệu.');
    }
    return data;
  }

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Object? data,
        // Map<String, dynamic>? data,
  }) async {
    final requestToken = accessToken;
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const ApiException('Phản hồi từ máy chủ không hợp lệ.');
      }
      if (body['success'] != true) {
        throw ApiException(
          _message(body),
          statusCode: response.statusCode,
          code: body['code'] as String?,
        );
      }
      return body['data'];
    } on DioException catch (error) {
      // Ignore late 401s from an old session. Only one callback clears a JWT.
      if (error.response?.statusCode == 401 &&
          path.startsWith('/visits/') &&
          requestToken != null &&
          requestToken == accessToken) {
        accessToken = null;
        await onVisitUnauthorized?.call();
      }
      final body = error.response?.data;
      if (body is Map<String, dynamic>) {
        throw ApiException(
          _message(body),
          statusCode: error.response?.statusCode,
          code: body['code'] as String?,
        );
      }
      final message = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Kết nối quá thời gian. Vui lòng thử lại.',
        DioExceptionType.connectionError =>
          'Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.',
        _ => 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
      };
      throw ApiException(
        message,
        statusCode: error.response?.statusCode,
        isUncertain: error.response == null,
      );
    }
  }

  String _message(Map<String, dynamic> body) {
    final message = body['message'];
    return message is String && message.trim().isNotEmpty
        ? message
        : 'Máy chủ không thể xử lý yêu cầu.';
  }

  void close() => _dio.close();
}
