import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  final api = ApiService();
  ref.onDispose(api.close);
  return api;
});

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
          if (options.extra['sessionVersion'] != null &&
              options.extra['sessionVersion'] != sessionVersion) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                message: 'Session changed before dispatch.',
              ),
            );
            return;
          }
          if (accessToken != null && !options.path.startsWith('/auth/')) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  String? _accessToken;
  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;
  String? get accessToken => _accessToken;
  set accessToken(String? value) {
    if (value != _accessToken) {
      _sessionVersion++;
      _accessToken = value;
    }
  }

  // Rotation preserves session identity so open chats and pending requests remain valid.
  void rotateAccessToken(String value) => _accessToken = value;
  Future<bool> Function()? onRefreshAccessToken;
  Future<bool>? _refreshing;
  Future<void> waitForRefresh() async {
    try {
      await _refreshing;
    } catch (_) {}
  }

  Future<bool> _refreshOnce() {
    final existing = _refreshing;
    if (existing != null) return existing;
    late final Future<bool> work;
    work =
        Future<bool>.sync(
          () async => await onRefreshAccessToken?.call() ?? false,
        ).whenComplete(() {
          if (identical(_refreshing, work)) _refreshing = null;
        });
    _refreshing = work;
    return work;
  }

  Future<void> _expire(int version) async {
    if (version != sessionVersion || accessToken == null) return;
    accessToken = null;
    await onVisitUnauthorized?.call();
  }

  Future<bool> _recover401(
    String path,
    int version,
    String? token,
    bool retried,
  ) async {
    if (!_expiresSession(path) || version != sessionVersion || token == null) {
      return false;
    }
    if (retried) {
      await _expire(version);
      return false;
    }
    if (accessToken != token) return accessToken != null;
    try {
      final refreshed = await _refreshOnce();
      if (version != sessionVersion) return false;
      if (refreshed && accessToken != null) return true;
      await _expire(version);
    } on ApiException catch (error) {
      if (error.isUnauthorized) await _expire(version);
      // Transport/server/storage errors preserve credentials and surface for a later retry.
      rethrow;
    }
    return false;
  }

  // Existing session-expiry hook, shared by Visits, Friends and private Locket.
  Future<void> Function()? onVisitUnauthorized;

  Future<Map<String, dynamic>> get(String path) async =>
      _object(await _request(path));

  Future<void> postVoid(String path, Map<String, dynamic> data) async {
    await _request(path, method: 'POST', data: data);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async => _object(await _request(path, method: 'POST', data: data));

  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, dynamic>? data,
  ]) async => _object(await _request(path, method: 'PUT', data: data));

  Future<void> putVoid(String path, [Map<String, dynamic>? data]) async {
    await _request(path, method: 'PUT', data: data);
  }

  Future<Map<String, dynamic>> delete(String path) async =>
      _object(await _request(path, method: 'DELETE'));

  Future<void> deleteWithBody(String path, Map<String, dynamic> data) async {
    await _request(path, method: 'DELETE', data: data);
  }

  /// One authenticated SSE connection. The caller cancels it on background/logout.
  Stream<Map<String, dynamic>> notificationEvents(CancelToken cancel) async* {
    final version = sessionVersion;
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final token = accessToken;
        try {
          final response = await _dio.get<ResponseBody>(
            '/notifications/stream',
            cancelToken: cancel,
            options: Options(
              responseType: ResponseType.stream,
              receiveTimeout: const Duration(seconds: 40),
              followRedirects: false,
              extra: {'sessionVersion': version},
              headers: {'Accept': 'text/event-stream'},
            ),
          );
          if (!(response.headers.value(Headers.contentTypeHeader) ?? '')
              .startsWith('text/event-stream')) {
            throw const ApiException('Máy chủ chưa hỗ trợ thông báo realtime.');
          }
          yield* decodeNotificationEvents(response.data!.stream);
          return;
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) return;
          if (e.response?.statusCode == 401 &&
              await _recover401(
                '/notifications/stream',
                version,
                token,
                attempt > 0,
              )) {
            if (cancel.isCancelled) return;
            continue;
          }
          throw ApiException(
            'Kết nối thông báo bị gián đoạn.',
            statusCode: e.response?.statusCode,
          );
        }
      }
    } finally {
      if (!cancel.isCancelled) cancel.cancel();
    }
  }

  /// Binary media stays in memory and uses the same JWT/401 handling as JSON.
  Future<Uint8List> getPrivateImage(String mediaId) async => Uint8List.fromList(
    (await _request(
      '/media/private/${Uri.encodeComponent(mediaId)}',
      responseType: ResponseType.bytes,
    )) as List<int>,
  );

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
    ResponseType responseType = ResponseType.json,
    bool retried = false,
    int? expectedSession,
  }) async {
    final version = expectedSession ?? sessionVersion;
    final requestToken = accessToken;
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(
          method: method,
          extra: {'sessionVersion': version},
          responseType: responseType,
          headers: responseType == ResponseType.bytes
              ? {'Accept': 'image/*'}
              : null,
          // Never forward a private-image request/JWT to a redirect target.
          followRedirects: false,
        ),
      );
      final body = response.data;
      if (responseType == ResponseType.bytes) return body;
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
      if (error.response?.statusCode == 401 &&
          await _recover401(path, version, requestToken, retried)) {
        return _request(
          path,
          method: method,
          data: data is FormData ? data.clone() : data,
          responseType: responseType,
          retried: true,
          expectedSession: version,
        );
      }
      final body = _errorBody(error.response?.data);
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

  bool _expiresSession(String path) {
    final endpoint = Uri.parse(path).path;
    return (onRefreshAccessToken != null &&
            !endpoint.startsWith('/auth/') &&
            !endpoint.startsWith('/places')) ||
        endpoint.startsWith('/visits/') ||
        endpoint == '/friends' ||
        endpoint.startsWith('/friends/') ||
        endpoint.startsWith('/locket/') ||
        endpoint == '/messages' ||
        endpoint.startsWith('/messages/') ||
        endpoint == '/notifications' ||
        endpoint.startsWith('/notifications/') ||
        endpoint == '/media/private' ||
        endpoint.startsWith('/media/private/');
  }

  dynamic _errorBody(dynamic body) {
    if (body is List<int>) {
      try {
        return jsonDecode(utf8.decode(body));
      } catch (_) {
        return null;
      }
    }
    return body;
  }

  String _message(Map<String, dynamic> body) {
    final message = body['message'];
    return message is String && message.trim().isNotEmpty
        ? message
        : 'Máy chủ không thể xử lý yêu cầu.';
  }

  void close() => _dio.close();
}

/// Decode frames across arbitrary UTF-8/network chunk boundaries; ignore comments/heartbeats.
Stream<Map<String, dynamic>> decodeNotificationEvents(
  Stream<List<int>> bytes,
) async* {
  String event = '';
  final data = <String>[];
  await for (final line
      in bytes
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (event == 'ready') yield {'type': 'READY'};
      if (event == 'notification' && data.isNotEmpty) {
        final value = jsonDecode(data.join('\n'));
        if (value is Map<String, dynamic>) yield value;
      }
      event = '';
      data.clear();
    } else if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      data.add(line.substring(5).trimLeft());
    }
  }
}
