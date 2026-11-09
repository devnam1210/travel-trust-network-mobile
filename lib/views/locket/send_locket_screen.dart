import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../services/locket_service.dart';
import '../auth/widgets/error_notice.dart';
import 'panorama_capture_screen.dart';

class SendLocketScreen extends ConsumerStatefulWidget {
  const SendLocketScreen({super.key, this.placeId, this.initialFilePath});

  /// Địa điểm gắn với ảnh (không bắt buộc)
  final String? placeId;

  /// Studio postcard (#4) sẽ truyền file đã xuất vào đây
  final String? initialFilePath;

  @override
  ConsumerState<SendLocketScreen> createState() => _SendLocketScreenState();
}

class _SendLocketScreenState extends ConsumerState<SendLocketScreen> {
  final _caption = TextEditingController();
  final _picker = ImagePicker();
  String? _filePath;
  bool _sending = false;
  String? _error;
  bool _is360 = false;

  @override
  void initState() {
    super.initState();
    _filePath = widget.initialFilePath;
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920, // nén bớt cho upload nhanh, tránh timeout 15s
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() {
          _filePath = file.path;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không mở được camera/thư viện ảnh.');
      }
    }
  }

  Future<void> _capture360() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PanoramaCaptureScreen()),
    );
    if (path != null && mounted) {
      setState(() {
        _filePath = path;
        _is360 = true;
        _error = null;
      });
    }
  }

  Future<void> _send() async {
    if (_filePath == null || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final service = ref.read(locketServiceProvider);
      // 1. Upload file → server trả URL
      final url = await service.uploadImage(_filePath!);
      // 2. Tạo signal Locket với URL đó
      await service.sendSignal(
        imageUrl: url,
        placeId: widget.placeId,
        caption: _caption.text.trim(),
        is360Image: _is360,
      );
      // 3. Làm mới feed
      ref.invalidate(locketFeedProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi ảnh lên Locket')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
              () => _error = e is ApiException
              ? e.message
              : 'Không gửi được ảnh. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Gửi ảnh Locket')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _filePath == null
                  ? ColoredBox(
                color: colors.surfaceContainerHighest,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 56),
                    SizedBox(height: 8),
                    Text('Chưa chọn ảnh'),
                  ],
                ),
              )
                  : Image.file(File(_filePath!), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sending ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Chụp ảnh'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sending ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Thư viện'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _sending ? null : _capture360,
            icon: const Icon(Icons.threesixty_rounded),
            label: const Text('Chụp ảnh 360°'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            enabled: !_sending,
            maxLength: 200, // khớp giới hạn caption ≤200 của backend
            decoration: const InputDecoration(
              labelText: 'Lời nhắn (không bắt buộc)',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _is360,
            onChanged: _sending ? null : (v) => setState(() => _is360 = v),
            secondary: const Icon(Icons.threesixty_rounded),
            title: const Text('Đây là ảnh 360°'),
            subtitle: const Text('Ảnh toàn cảnh, tỉ lệ khoảng 2:1'),
          ),
          if (_error != null) ...[
            ErrorNotice(message: _error!),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _filePath == null || _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'Đang gửi…' : 'Gửi'),
          ),
        ],
      ),
    );
  }
}