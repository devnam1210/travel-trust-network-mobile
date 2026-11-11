import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../auth/auth_controller.dart';
import 'notification_model.dart';
import 'push_gateway.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(apiServiceProvider)),
);

final unreadNotificationsProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  if (ref.watch(authControllerProvider.select((a) => a.user?.id)) == null) {
    return 0;
  }
  return ref.watch(notificationServiceProvider).unread();
});

// Screens can refresh immediately for a new event, preserving drafts and pagination.
final notificationEventProvider =
    NotifierProvider<NotificationEvent, AppNotification?>(
      NotificationEvent.new,
    );

class NotificationEvent extends Notifier<AppNotification?> {
  @override
  AppNotification? build() => null;
  void receive(AppNotification? event) => state = event;
}

final pushRegistrationProvider = Provider<PushRegistration>(
  (ref) => PushRegistration(
    ref.watch(notificationServiceProvider),
    ref.watch(pushGatewayProvider),
  ),
);

/// Serialize token rotation and logout, so a late registration cannot restore an old account binding.
class PushRegistration {
  PushRegistration(this.service, this.gateway);
  final NotificationService service;
  final PushGateway gateway;
  Future<void> _work = Future.value();
  String? _token;
  int? _registeredJwt;
  int _generation = 0;

  Future<void> register(String token) {
    final generation = _generation;
    return _work = _work
        .then((_) async {
          if (generation != _generation) return;
          final jwt = service.api.sessionVersion;
          await service.register(token);
          _token = token;
          _registeredJwt = jwt;
        })
        .catchError((Object _) {});
  }

  Future<void> detach() {
    _generation++;
    return _work = _work.then((_) async {
      final token = _token;
      _token = null;
      try {
        if (token != null && _registeredJwt == service.api.sessionVersion) {
          await service.unregister(token);
        }
      } catch (_) {}
      _registeredJwt = null;
      // Also revoke with Firebase: an expired JWT cannot unregister through the backend.
      try {
        await gateway.deleteToken();
      } catch (_) {}
    });
  }
}

class NotificationService {
  NotificationService(this.api);
  final ApiService api;
  static const pageSize = 30;

  Stream<Map<String, dynamic>> events(CancelToken cancel) =>
      api.notificationEvents(cancel);
  Future<List<AppNotification>> history({
    String? before,
  }) async => (await api.getList(
    '/notifications?size=$pageSize${before == null ? '' : '&before=$before'}',
  )).map((j) => AppNotification.fromJson(j as Map<String, dynamic>)).toList();
  Future<int> unread() async =>
      (await api.get('/notifications/unread-count'))['count'] as int? ?? 0;
  Future<void> read(String id) => api.putVoid('/notifications/$id/read');
  Future<void> register(String token) =>
      api.putVoid('/notifications/devices', {'token': token});
  Future<void> unregister(String token) =>
      api.deleteWithBody('/notifications/devices', {'token': token});
}
