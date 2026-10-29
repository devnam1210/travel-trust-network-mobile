import 'package:dio/dio.dart';

import '../config/app_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

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

  Future<Map<String, dynamic>> get(String path) => _request(path);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) =>
      _request(path, data: data);

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = data == null
          ? await _dio.get<dynamic>(path)
          : await _dio.post<dynamic>(path, data: data);
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
      final result = body['data'];
      if (result is! Map<String, dynamic>) {
        throw const ApiException('Phản hồi từ máy chủ thiếu dữ liệu.');
      }
      return result;
    } on DioException catch (error) {
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
      throw ApiException(message, statusCode: error.response?.statusCode);
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
