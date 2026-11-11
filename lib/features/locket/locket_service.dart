import 'dart:typed_data';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../auth/auth_controller.dart' show authControllerProvider;
import 'locket_model.dart';
import 'locket_widget_service.dart';

final locketServiceProvider = Provider<LocketService>(
  (ref) => LocketService(api: ref.watch(apiServiceProvider)),
);

final locketFeedProvider = FutureProvider.autoDispose<List<LocketSignal>>((
  ref,
) {
  final userId = ref.watch(authControllerProvider.select((a) => a.user?.id));
  if (userId == null) {
    unawaited(LocketWidgetService.updateFromFeed(const []));
    return [];
  }
  return ref.watch(locketServiceProvider).getFeed().then((feed) {
    if (ref.mounted && ref.read(authControllerProvider).user?.id == userId) {
      unawaited(LocketWidgetService.updateFromFeed(feed));
    }
    return feed;
  });
});

final locketHistoryProvider = FutureProvider.autoDispose
    .family<List<LocketSignal>, String>((ref, kind) {
      final userId = ref.watch(
        authControllerProvider.select((a) => a.user?.id),
      );
      if (userId == null) return [];
      return ref.watch(locketServiceProvider).getHistory(kind: kind);
    });

final privateLocketImageProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, mediaId) {
      final userId = ref.watch(
        authControllerProvider.select((a) => a.user?.id),
      );
      if (userId == null) return null;
      return ref.watch(apiServiceProvider).getPrivateImage(mediaId);
    });

class LocketService {
  LocketService({required this.api});
  final ApiService api;
  static const pageSize = 20;
  static const emojis = ['❤️', '😂', '😍', '😮', '😢', '🔥', '👍'];

  Future<List<LocketSignal>> getFeed({int page = 0}) => _list(
    page == 0 ? '/locket/feed' : '/locket/feed?page=$page&size=$pageSize',
  );

  Future<List<LocketSignal>> getHistory({String kind = 'all', int page = 0}) =>
      _list('/locket/history?kind=$kind&page=$page&size=$pageSize');

  Future<List<LocketSignal>> getUserPosts(
    String userId, {
    int page = 0,
  }) => _list(
    '/locket/users/${Uri.encodeComponent(userId)}/posts?page=$page&size=$pageSize',
  );

  Future<List<LocketSignal>> _list(String path) async =>
      (await api.getList(path))
          .map((e) => LocketSignal.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

  /// Returns an owned private media ID, never a public URL.
  Future<String> uploadImage(String filePath) async =>
      (await api.upload('/media/private', filePath))['mediaId'] as String;

  Future<LocketSignal> sendSignal({
    required String mediaId,
    List<String> recipientIds = const [],
    bool allFriends = false,
    String? placeId,
    String? caption,
    bool is360Image = false,
  }) async => LocketSignal.fromJson(
    await api.post('/locket/send-signal', {
      'mediaId': mediaId,
      'recipientIds': recipientIds,
      'allFriends': allFriends,
      'placeId': ?placeId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      'is360Image': is360Image,
    }),
  );

  Future<LocketSignal> react(String id, String? emoji) async =>
      LocketSignal.fromJson(
        emoji == null
            ? await api.delete('/locket/$id/reaction')
            : await api.put('/locket/$id/reaction', {'emoji': emoji}),
      );
}
