import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';
import '../models/locket_model.dart';
import 'api_service.dart';

final locketServiceProvider = Provider<LocketService>(
      (ref) => LocketService(api: ref.watch(apiServiceProvider)),
);

/// Feed tách theo user đang đăng nhập, tự giải phóng khi rời màn.
final locketFeedProvider = FutureProvider.autoDispose<List<LocketSignal>>((ref) {
  final userId = ref.watch(authControllerProvider.select((a) => a.user?.id));
  if (userId == null) return [];
  return ref.watch(locketServiceProvider).getFeed();
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

  Future<String> uploadImage(String filePath) async {
    final data = await api.upload('/media/upload', filePath);
    return data['url'] as String;
  }

  Future<LocketSignal> sendSignal({
    required String imageUrl,
    String? placeId,
    String? caption,
    bool is360Image = false,
  }) async => LocketSignal.fromJson(
    await api.post('/locket/send-signal', {
      'imageUrl': imageUrl,
      if (placeId != null) 'placeId': placeId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      'is360Image': is360Image,
    }),
  );
}