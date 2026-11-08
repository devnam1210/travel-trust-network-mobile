import 'package:flutter/material.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

/// Xem 1 ảnh Locket toàn màn hình.
/// - Ảnh 360°: kéo để xoay; bật nút cảm biến để nghiêng máy nhìn quanh.
/// - Ảnh thường: phóng to/thu nhỏ bằng 2 ngón tay.
class LocketImageScreen extends StatefulWidget {
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
  State<LocketImageScreen> createState() => _LocketImageScreenState();
}

class _LocketImageScreenState extends State<LocketImageScreen> {
  // Mặc định tắt cảm biến: emulator không có con quay thật, dễ làm ảnh đứng yên
  bool _useSensor = false;

  @override
  Widget build(BuildContext context) {
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
        child: widget.is360 ? _panorama() : _normal(),
      ),
    );
  }

  Widget _panorama() => Stack(
    children: [
      // Ép viewer chiếm hết màn hình, nếu không sẽ bị kích thước 0 (màn đen)
      Positioned.fill(
        child: PanoramaViewer(
          // key đổi khi bật/tắt cảm biến để viewer khởi tạo lại đúng chế độ
          key: ValueKey(_useSensor),
          sensorControl:
          _useSensor ? SensorControl.orientation : SensorControl.none,
          child: Image.network(widget.imageUrl),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 24,
        child: Center(
          child: Chip(
            avatar: const Icon(Icons.threesixty_rounded, size: 18),
            label: Text(
              _useSensor
                  ? 'Nghiêng máy hoặc kéo để xoay'
                  : 'Kéo sang trái/phải để xoay',
            ),
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
        widget.imageUrl,
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