import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../services/locket_service.dart';
import '../../services/visit_service.dart';
import '../locket/send_locket_screen.dart';

/// Studio postcard: ảnh nền + khung + sticker + chữ + tem GPS.
/// Bấm "Dùng postcard này" → upload và pop(url) về màn gọi.
class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({
    super.key,
    required this.placeId,
    required this.placeName,
    this.visitId,
  });

  final String placeId;
  final String placeName;
  final String? visitId;

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _Layer {
  _Layer(this.text, {this.isSticker = false});

  final String text;
  final bool isSticker;
  Offset pos = const Offset(0.5, 0.5); // tỉ lệ 0..1 trên khung
  double scale = 1;
  double rotation = 0;
}

class _Frame {
  const _Frame(this.name, this.color, this.side, this.bottom);

  final String name;
  final Color color;
  final double side;
  final double bottom;
}

const _frames = [
  _Frame('Không', Colors.transparent, 0, 0),
  _Frame('Polaroid', Colors.white, 14, 48),
  _Frame('Vàng', Color(0xFFD4A017), 12, 12),
  _Frame('Đen', Color(0xFF212121), 12, 12),
];

const _stickers = ['❤️', '⭐', '🌴', '🏖️', '⛰️', '📍', '✈️', '📸', '😍', '🔥'];

class _StudioScreenState extends ConsumerState<StudioScreen> {
  final _canvasKey = GlobalKey();
  final _picker = ImagePicker();
  final _layers = <_Layer>[];

  String? _bgPath;
  _Frame _frame = _frames[1];
  _Layer? _selected;
  bool _busy = false;
  String? _error;

  // Giá trị gốc lúc bắt đầu cử chỉ
  double _baseScale = 1;
  double _baseRotation = 0;

  Future<void> _pickBackground(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file != null && mounted) setState(() => _bgPath = file.path);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không mở được camera/thư viện ảnh.');
    }
  }

  Future<void> _addText() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm chữ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null && text.isNotEmpty) _addLayer(_Layer(text));
  }

  void _addLayer(_Layer layer) => setState(() {
    _layers.add(layer);
    _selected = layer;
  });

  void _deleteSelected() {
    if (_selected == null) return;
    setState(() {
      _layers.remove(_selected);
      _selected = null;
    });
  }

  /// Xuất khung postcard ra file PNG tạm.
  Future<String> _export() async {
    setState(() => _selected = null); // bỏ viền chọn khỏi ảnh
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '${Directory.systemTemp.path}/postcard_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file.path;
  }

  Future<void> _useForReview() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = await _export();
      final url = await ref.read(locketServiceProvider).uploadImage(path);
      if (mounted) Navigator.of(context).pop(url);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Không xuất được postcard. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendToLocket() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _export();
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              SendLocketScreen(placeId: widget.placeId, initialFilePath: path),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Không xuất được postcard.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visits = ref.watch(visitHistoryProvider).value ?? const [];
    final verified = visits
        .where(
          (v) =>
              v.status == 'VERIFIED' &&
              (widget.visitId != null
                  ? v.id == widget.visitId
                  : v.placeId == widget.placeId),
        )
        .firstOrNull;
    final when = verified == null
        ? null
        : (verified.checkOutTime ?? verified.checkInTime).toLocal();
    final stamp = when == null
        ? null
        : '✓ ĐÃ XÁC MINH GPS · ${widget.placeName} · '
              '${when.day}/${when.month}/${when.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio postcard'),
        actions: [
          IconButton(
            tooltip: 'Xóa lớp đang chọn',
            onPressed: _selected == null ? null : _deleteSelected,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: _buildCanvas(colors, stamp)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickBackground(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Chụp'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickBackground(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Thư viện'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _addText,
                  icon: const Icon(Icons.text_fields),
                  label: const Text('Chữ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Khung', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: [
              for (final f in _frames)
                ChoiceChip(
                  label: Text(f.name),
                  selected: _frame == f,
                  onSelected: (_) => setState(() => _frame = f),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Sticker', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 4,
            children: [
              for (final s in _stickers)
                InkWell(
                  onTap: () => _addLayer(_Layer(s, isSticker: true)),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(s, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
          if (stamp == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Chưa có chuyến đi đã xác minh tại đây nên chưa có tem GPS.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: colors.error)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _useForReview,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'Đang xử lý…' : 'Dùng postcard này'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _sendToLocket,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Gửi lên Locket'),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(ColorScheme colors, String? stamp) {
    return AspectRatio(
      aspectRatio: 1,
      child: RepaintBoundary(
        key: _canvasKey,
        child: Container(
          color: _frame.color,
          padding: EdgeInsets.fromLTRB(
            _frame.side,
            _frame.side,
            _frame.side,
            _frame.bottom,
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              return ClipRect(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = null),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_bgPath != null)
                        Image.file(File(_bgPath!), fit: BoxFit.cover)
                      else
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [colors.primary, colors.tertiary],
                            ),
                          ),
                        ),
                      for (final l in _layers) _buildLayer(l, size),
                      if (stamp != null)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              stamp,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLayer(_Layer l, Size size) {
    final selected = identical(l, _selected);
    return Positioned(
      left: l.pos.dx * size.width,
      top: l.pos.dy * size.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onTap: () => setState(() => _selected = l),
          onScaleStart: (_) {
            _baseScale = l.scale;
            _baseRotation = l.rotation;
            setState(() => _selected = l);
          },
          onScaleUpdate: (d) => setState(() {
            l.pos = Offset(
              (l.pos.dx + d.focalPointDelta.dx / size.width).clamp(0.0, 1.0),
              (l.pos.dy + d.focalPointDelta.dy / size.height).clamp(0.0, 1.0),
            );
            l.scale = (_baseScale * d.scale).clamp(0.3, 6.0);
            l.rotation = _baseRotation + d.rotation;
          }),
          child: Transform.rotate(
            angle: l.rotation,
            child: Transform.scale(
              scale: l.scale,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: selected
                    ? BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                      )
                    : null,
                child: Text(
                  l.text,
                  style: TextStyle(
                    fontSize: l.isSticker ? 48 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: l.isSticker
                        ? null
                        : const [Shadow(blurRadius: 4, color: Colors.black87)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
