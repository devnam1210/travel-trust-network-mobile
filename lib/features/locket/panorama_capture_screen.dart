import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

const _shots = 8; // 8 tấm × ~45° = 360°
const _outW = 1920; // ảnh 360 cần tỉ lệ 2:1
const _outH = 960;

/// Chụp 8 tấm khi xoay quanh người, ghép ngang thành ảnh 2:1.
/// Đây là cách ghép đơn giản (cắt dải giữa + nối), không phải stitching chuẩn.
class PanoramaCaptureScreen extends StatefulWidget {
  const PanoramaCaptureScreen({super.key});

  @override
  State<PanoramaCaptureScreen> createState() => _PanoramaCaptureScreenState();
}

class _PanoramaCaptureScreenState extends State<PanoramaCaptureScreen> {
  CameraController? _camera;
  final _paths = <String>[];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final c = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _camera = c);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không mở được camera.');
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    if (_busy || _camera == null) return;
    setState(() => _busy = true);
    try {
      _paths.add((await _camera!.takePicture()).path);
      if (_paths.length == _shots) {
        final out =
            '${Directory.systemTemp.path}/pano_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await compute(_stitch, [..._paths, out]);
        if (mounted) Navigator.of(context).pop(out);
        return;
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Chụp lỗi, thử lại.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cam = _camera;
    return Scaffold(
      appBar: AppBar(title: const Text('Chụp ảnh 360°')),
      body: _error != null
          ? Center(child: Text(_error!))
          : cam == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: Center(child: CameraPreview(cam))),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _busy && _paths.length == _shots
                            ? 'Đang ghép ảnh…'
                            : 'Đứng yên một chỗ, xoay sang phải khoảng 45° rồi chụp tiếp (${_paths.length}/$_shots)',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _paths.length / _shots),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _shoot,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Chụp'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// args = [ảnh1..ảnhN, đường dẫn file xuất]. Chạy ở isolate riêng cho khỏi đơ UI.
void _stitch(List<String> args) {
  final out = args.last;
  final srcs = args.sublist(0, args.length - 1);
  final tileW = _outW ~/ srcs.length;
  final canvas = img.Image(width: _outW, height: _outH);
  for (var i = 0; i < srcs.length; i++) {
    final raw = img.decodeImage(File(srcs[i]).readAsBytesSync())!;
    final pic = img.bakeOrientation(raw);
    // Lấy dải giữa ~70% bề ngang (phần chồng lấn mép bỏ đi) rồi co về ô 1/8
    final cropW = (pic.width * 0.7).round();
    final strip = img.copyCrop(
      pic,
      x: (pic.width - cropW) ~/ 2,
      y: 0,
      width: cropW,
      height: pic.height,
    );
    final tile = img.copyResize(strip, width: tileW, height: _outH);
    img.compositeImage(canvas, tile, dstX: i * tileW, dstY: 0);
  }
  File(out).writeAsBytesSync(img.encodeJpg(canvas, quality: 85));
}
