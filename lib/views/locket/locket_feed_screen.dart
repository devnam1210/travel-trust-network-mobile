import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../models/locket_model.dart';
import '../../services/api_service.dart';
import '../../services/locket_service.dart';

class LocketFeedScreen extends ConsumerWidget {
  const LocketFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(locketFeedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Locket')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(locketFeedProvider.future),
        child: feed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(32),
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(
                e is ApiException ? e.message : 'Không tải được Locket.',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => ref.invalidate(locketFeedProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(48),
            children: const [
              Icon(Icons.photo_library_outlined, size: 48),
              SizedBox(height: 12),
              Text('Chưa có ảnh nào.', textAlign: TextAlign.center),
            ],
          )
              : GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _LocketTile(signal: items[i]),
          ),
        ),
      ),
    );
  }
}

class _LocketTile extends StatelessWidget {
  const _LocketTile({required this.signal});
  final LocketSignal signal;

  @override
  Widget build(BuildContext context) {
    final url = signal.imageUrl.isEmpty
        ? null
        : Uri.parse(AppConfig.apiBaseUrl).resolve(signal.imageUrl).toString();
    final caption = signal.caption?.isNotEmpty == true ? ': ${signal.caption}' : '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null)
            const ColoredBox(color: Colors.black12)
          else
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${signal.senderName}$caption',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (signal.placeName != null)
                    Text(
                      '📍 ${signal.placeName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          if (signal.is360Image)
            const Positioned(
              top: 8,
              right: 8,
              child: Chip(label: Text('360°'), visualDensity: VisualDensity.compact),
            ),
        ],
      ),
    );
  }
}