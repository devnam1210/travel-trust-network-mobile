import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';
import '../models/locket_model.dart';
import 'api_service.dart';
import 'locket_widget_service.dart';

final locketServiceProvider = Provider<LocketService>(
      (ref) => LocketService(api: ref.watch(apiServiceProvider)),
);

/// Feed tách theo user đang đăng nhập, tự giải phóng khi rời màn.
final locketFeedProvider = FutureProvider.autoDispose<List<LocketSignal>>((ref) {
  final userId = ref.watch(authControllerProvider.select((a) => a.user?.id));
  if (userId == null) return [];
  return ref.watch(locketServiceProvider).getFeed().then((feed) {
    unawaited(LocketWidgetService.updateFromFeed(feed));
    return feed;
  });
});

class LocketService {
  LocketService({required this.api});

  final ApiService api;

  Future<List<LocketSignal>> getFeed() async {
    final data = await api.getList('/locket/feed');
    return data
        .map((e) => LocketSignal.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Upload ảnh, trả về URL tương đối dạng `/uploads/{uuid}.{ext}`
  Future<String> uploadImage(String filePath) async {
    final data = await api.upload('/media/upload', filePath);
    return data['url'] as String;
  }

  Future<LocketSignal> sendSignal({
    required String imageUrl,
    String? placeId,
    String? caption,
    bool is360Image = false,
  }) async {
    final trimmed = caption?.trim();
    return LocketSignal.fromJson(
      await api.post('/locket/send-signal', {
        'imageUrl': imageUrl,
        'placeId': ?placeId, // null thì không gửi
        'caption': ?(trimmed == null || trimmed.isEmpty ? null : trimmed),
        'is360Image': is360Image,
      }),
    );
  }
}