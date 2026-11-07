import 'package:flutter/material.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

/// Xem 1 ảnh Locket toàn màn hình.
/// - Ảnh 360°: kéo để xoay, nghiêng máy để nhìn quanh (cảm biến hướng).
/// - Ảnh thường: phóng to/thu nhỏ bằng 2 ngón tay.
class LocketImageScreen extends StatelessWidget {
  const LocketImageScreen({
    super.key,
    required this.imageUrl,
    required this.is360,
    this.title,
  });

  final String imageUrl;
  final bool is360;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title ?? (is360 ? 'Ảnh 360°' : 'Ảnh')),
      ),
      body: is360 ? _panorama() : _normal(),
    );
  }

  Widget _panorama() => Stack(
    children: [
      PanoramaViewer(
        sensorControl: SensorControl.orientation,
        child: Image.network(imageUrl),
      ),
      const Positioned(
        left: 0,
        right: 0,
        bottom: 24,
        child: Center(
          child: Chip(
            avatar: Icon(Icons.threesixty_rounded, size: 18),
            label: Text('Kéo hoặc nghiêng máy để xoay'),
          ),
        ),
      ),
    ],
  );

  Widget _normal() => InteractiveViewer(
    minScale: 1,
    maxScale: 4,
    child: Center(
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 64,
        ),
      ),
    ),
  );
}