import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../auth/auth_controller.dart';
import 'message_model.dart';

final messageServiceProvider = Provider<MessageService>(
  (ref) => MessageService(ref.watch(apiServiceProvider)),
);
final inboxProvider = FutureProvider.autoDispose<List<Conversation>>((ref) {
  if (ref.watch(authControllerProvider.select((a) => a.user?.id)) == null) {
    return [];
  }
  return ref.watch(messageServiceProvider).inbox();
});
final unreadMessagesProvider = FutureProvider.autoDispose<int>((ref) async {
  if (ref.watch(authControllerProvider.select((a) => a.user?.id)) == null) {
    return 0;
  }
  return ref.watch(messageServiceProvider).unread();
});

class MessageService {
  MessageService(this.api);
  final ApiService api;
  static const pageSize = 50;
  static const _base = '/messages/conversations';
  Future<int> unread() async =>
      ((await api.get('$_base/unread-count'))['count'] as num?)?.toInt() ?? 0;
  Future<void> markRead(String id, int cursor) =>
      api.putVoid('$_base/$id/read', {'lastReadMessageId': cursor});
  Future<List<Conversation>> inbox({int page = 0}) async =>
      (await api.getList('$_base?page=$page&size=30'))
          .map((j) => Conversation.fromJson(j as Map<String, dynamic>))
          .toList();
  Future<Conversation> open(String peer) async =>
      Conversation.fromJson(await api.post('$_base/with/$peer', {}));
  Future<Conversation> get(String id) async =>
      Conversation.fromJson(await api.get('$_base/$id'));
  Future<List<ChatMessage>> history(
    String id, {
    int? before,
    int? after,
  }) async => (await api.getList(
    '$_base/$id/messages?size=$pageSize${before == null ? '' : '&before=$before'}${after == null ? '' : '&after=$after'}',
  )).map((j) => ChatMessage.fromJson(j as Map<String, dynamic>)).toList();
  Future<ChatMessage> send(
    String id, {
    required String clientId,
    required String body,
    String? quotedSignalId,
  }) async => ChatMessage.fromJson(
    await api.post('$_base/$id/messages', {
      'clientMessageId': clientId,
      'body': body,
      'quotedSignalId': ?quotedSignalId,
    }),
  );

  /// A stable random UUID per send attempt allows safe retries after a lost response.
  static String newClientId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
