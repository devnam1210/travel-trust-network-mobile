import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_service.dart';
import '../../shared/widgets/error_notice.dart';
import '../../shared/motion/app_motion.dart';
import '../../shared/widgets/motion_feedback.dart';
import '../auth/auth_controller.dart';
import '../friends/friend_service.dart';
import 'locket_recipients.dart';
import 'locket_service.dart';

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
  bool _picking = false;
  bool _allFriends = true;
  bool _uncertain = false;
  String? _mediaId;
  final _selected = <String>{};
  List<String> _retryTargets = [];
  String? _error;

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

  Future<void> _pickImage(ImageSource source) async {
    if (_picking || _sending || _uncertain) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920, // nén bớt cho upload nhanh, tránh timeout 15s
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() {
          _filePath = file.path;
          _mediaId = null;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không mở được camera/thư viện ảnh.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _sendLocket() async {
    if (_filePath == null || _sending || _picking) return;
    final user = ref.read(authControllerProvider).user?.id;
    if (user == null) return;
    final friends = ref.read(friendsProvider('friends'));
    if (!_uncertain &&
        (friends.isLoading || friends.hasError || !friends.hasValue)) {
      return;
    }
    final people = friends.asData?.value.map((f) => f.id).toSet() ?? <String>{};
    final targets = _uncertain
        ? _retryTargets
        : _selected.intersection(people).toList();
    if (!_uncertain && (people.isEmpty || (!_allFriends && targets.isEmpty))) {
      return;
    }
    if (!_uncertain) _retryTargets = targets;
    final caption = _caption.text.trim();
    final token = ref.read(apiServiceProvider).accessToken;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final service = ref.read(locketServiceProvider);
      // Keep the owned upload ID for retries. The backend uses it to prevent duplicate sends.
      _mediaId ??= await service.uploadImage(_filePath!);
      if (!mounted ||
          ref.read(authControllerProvider).user?.id != user ||
          ref.read(apiServiceProvider).accessToken != token) {
        return;
      }
      await service.sendSignal(
        mediaId: _mediaId!,
        allFriends: _allFriends,
        recipientIds: _allFriends ? [] : targets,
        placeId: widget.placeId,
        caption: caption,
      );
      if (!mounted ||
          ref.read(authControllerProvider).user?.id != user ||
          ref.read(apiServiceProvider).accessToken != token) {
        return;
      }
      // 3. Làm mới feed
      ref.invalidate(locketFeedProvider);
      ref.invalidate(locketHistoryProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã gửi ảnh lên Locket')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uncertain = _mediaId != null && e is ApiException && e.isUncertain;
          _error = _uncertain
              ? 'Chưa xác nhận được kết quả gửi. Nhấn Gửi để kiểm tra lại cùng ảnh này.'
              : e is ApiException
              ? e.message
              : 'Không gửi được ảnh. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final friends = ref.watch(friendsProvider('friends'));
    final people = friends.asData?.value.map((f) => f.id).toSet() ?? <String>{};
    final canSend =
        _uncertain ||
        (!friends.isLoading &&
            !friends.hasError &&
            people.isNotEmpty &&
            (_allFriends || _selected.intersection(people).isNotEmpty));
    final editable = !_sending && !_picking && !_uncertain;
    if (ref.watch(authControllerProvider.select((a) => a.user?.id)) == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gửi ảnh Locket')),
        body: const Center(child: Text('Vui lòng đăng nhập lại.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Gửi ảnh Locket')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: MotionSwitcher(
                child: SizedBox.expand(
                  key: ValueKey(_filePath),
                  child: _filePath == null
                      ? ColoredBox(
                          key: const ValueKey('empty-preview'),
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
                      : Image.file(
                          File(_filePath!),
                          key: ValueKey(_filePath),
                          fit: BoxFit.cover,
                          cacheWidth: AppMotion.imageWidth(
                            context,
                            MediaQuery.sizeOf(context).width - 40,
                          ),
                          frameBuilder: AppMotion.imageFrame,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !editable
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Chụp ảnh'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !editable
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Thư viện'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            enabled: editable,
            maxLength: 200, // khớp giới hạn caption ≤200 của backend
            decoration: const InputDecoration(
              labelText: 'Lời nhắn (không bắt buộc)',
              border: OutlineInputBorder(),
            ),
          ),
          LocketRecipients(
            allFriends: _allFriends,
            selected: _selected,
            enabled: editable,
            onAllChanged: (value) => setState(() => _allFriends = value),
            onSelected: (id, selected) => setState(() {
              if (selected) {
                _selected.add(id);
              } else {
                _selected.remove(id);
              }
            }),
          ),
          if (_error != null) ...[
            ErrorNotice(message: _error!),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _filePath == null || _sending || _picking || !canSend
                ? null
                : _sendLocket,
            icon: BusyIcon(busy: _sending, icon: Icons.send_rounded, size: 18),
            label: Text(_sending ? 'Đang gửi…' : 'Gửi'),
          ),
        ],
      ),
    );
  }
}
