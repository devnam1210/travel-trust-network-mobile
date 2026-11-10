import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../auth/auth_controller.dart';
import 'friend_model.dart';

final friendServiceProvider = Provider<FriendService>(
  (ref) => FriendService(api: ref.watch(apiServiceProvider)),
);

final friendsProvider = FutureProvider.autoDispose
    .family<List<FriendUser>, String>((ref, kind) {
      final user = ref.watch(authControllerProvider.select((a) => a.user?.id));
      if (user == null) return [];
      return ref.watch(friendServiceProvider).list(kind);
    });

class FriendService {
  FriendService({required this.api});
  final ApiService api;

  Future<FriendUser> profile(String userId) async => FriendUser.fromJson(
    await api.get('/friends/users/${Uri.encodeComponent(userId)}/profile'),
  );

  Future<List<FriendUser>> list([String kind = 'friends']) =>
      _list('/friends?kind=${Uri.encodeQueryComponent(kind)}');

  Future<List<FriendUser>> search(String query) => _list(
    '/friends/search?username=${Uri.encodeQueryComponent(query.trim())}',
  );

  Future<List<FriendUser>> _list(String path) async =>
      (await api.getList(path))
          .map((e) => FriendUser.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

  Future<void> request(String target) async {
    await api.post('/friends/requests/${Uri.encodeComponent(target)}', {});
  }

  Future<void> accept(String id) async {
    await api.put('/friends/requests/${Uri.encodeComponent(id)}/accept');
  }

  Future<void> remove(String id, String action) async {
    await api.delete('/friends/${Uri.encodeComponent(id)}/$action');
  }

  Future<String> updateUsername(String username) async =>
      (await api.put('/friends/username', {
            'username': username.trim(),
          }))['username']
          as String;
}
