import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locket_service.dart';
import '../../shared/motion/app_motion.dart';

/// Authenticated bytes only: no public URL, disk cache or JWT in a query string.
class PrivateLocketImage extends ConsumerStatefulWidget {
  const PrivateLocketImage({super.key, required this.mediaId});
  final String mediaId;
  @override
  ConsumerState<PrivateLocketImage> createState() => _PrivateLocketImageState();
}

class _PrivateLocketImageState extends ConsumerState<PrivateLocketImage> {
  MemoryImage? _source;
  ImageProvider? _image;
  int? _decodeWidth;

  void _clearImage() {
    final previous = _image;
    _image = null;
    _source = null;
    _decodeWidth = null;
    if (previous != null) unawaited(previous.evict());
  }

  @override
  void dispose() {
    _clearImage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(privateLocketImageProvider(widget.mediaId));
    if (data.isLoading || !data.hasValue || data.value == null) _clearImage();
    return data.when(
      skipLoadingOnRefresh: false,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: IconButton(
          tooltip: 'Tải lại ảnh',
          onPressed: () =>
              ref.invalidate(privateLocketImageProvider(widget.mediaId)),
          icon: const Icon(Icons.broken_image_outlined),
        ),
      ),
      data: (bytes) {
        if (bytes == null) return const ColoredBox(color: Colors.black12);
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = AppMotion.imageWidth(
              context,
              constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width,
            );
            if (_source?.bytes != bytes || _decodeWidth != width) {
              _clearImage();
              _source = MemoryImage(bytes);
              _image = ResizeImage.resizeIfNeeded(width, null, _source!);
              _decodeWidth = width;
            }
            return Image(
              image: _image!,
              fit: BoxFit.cover,
              frameBuilder: AppMotion.imageFrame,
              // Never retain outgoing private pixels across media/account changes.
              gaplessPlayback: false,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            );
          },
        );
      },
    );
  }
}
