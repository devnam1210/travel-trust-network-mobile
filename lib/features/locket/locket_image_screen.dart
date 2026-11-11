import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

import 'locket_service.dart';

/// Full-screen zoom and panorama using authenticated, memory-only media bytes.
class LocketImageScreen extends ConsumerStatefulWidget {
  const LocketImageScreen({
    super.key,
    required this.mediaId,
    required this.is360,
    this.title,
  });
  final String mediaId;
  final bool is360;
  final String? title;

  @override
  ConsumerState<LocketImageScreen> createState() => _LocketImageScreenState();
}

class _LocketImageScreenState extends ConsumerState<LocketImageScreen> {
  bool _useSensor = false;
  MemoryImage? _image;

  void _clear() {
    final previous = _image;
    _image = null;
    if (previous != null) unawaited(previous.evict());
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  Widget _photo(Uint8List? bytes) {
    if (bytes == null) {
      _clear();
      return const SizedBox.shrink();
    }
    if (_image?.bytes != bytes) {
      _clear();
      _image = MemoryImage(bytes);
    }
    final image = Image(
      image: _image!,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.broken_image_outlined, color: Colors.white54),
    );
    if (!widget.is360) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(child: image),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: PanoramaViewer(
            key: ValueKey(_useSensor),
            sensorControl: _useSensor
                ? SensorControl.orientation
                : SensorControl.none,
            child: image,
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: Chip(
              avatar: Icon(Icons.threesixty_rounded, size: 18),
              label: Text('Kéo sang trái/phải để xoay'),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = ref.watch(privateLocketImageProvider(widget.mediaId));
    if (photo.isLoading || !photo.hasValue) _clear();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? (widget.is360 ? 'Ảnh 360°' : 'Ảnh')),
        actions: [
          if (widget.is360)
            IconButton(
              tooltip: _useSensor ? 'Tắt cảm biến' : 'Bật cảm biến',
              icon: Icon(
                _useSensor
                    ? Icons.screen_rotation_rounded
                    : Icons.screen_lock_rotation_rounded,
              ),
              onPressed: () => setState(() => _useSensor = !_useSensor),
            ),
        ],
      ),
      body: SizedBox.expand(
        child: photo.when(
          skipLoadingOnRefresh: false,
          data: _photo,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: IconButton(
              tooltip: 'Tải lại ảnh',
              onPressed: () =>
                  ref.invalidate(privateLocketImageProvider(widget.mediaId)),
              icon: const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
