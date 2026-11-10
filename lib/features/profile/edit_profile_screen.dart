import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/user_model.dart';
import '../../core/api_service.dart';
import '../../shared/widgets/error_notice.dart';
import '../../shared/motion/app_motion.dart';
import '../../shared/widgets/motion_feedback.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.currentUser});

  final UserModel currentUser;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _avatarUrlController;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser.fullName);
    _bioController = TextEditingController(text: widget.currentUser.bio ?? '');
    _avatarUrlController = TextEditingController(
      text: widget.currentUser.avatarUrl ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final controller = ref.read(authControllerProvider.notifier);
      await controller.updateProfile(
        fullName: _nameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim().isEmpty
            ? null
            : _avatarUrlController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật hồ sơ thành công!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Không thể cập nhật hồ sơ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar Preview
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: colors.primaryContainer,
                            foregroundColor: colors.onPrimaryContainer,
                            backgroundImage:
                                _avatarUrlController.text.trim().isNotEmpty
                                ? ResizeImage.resizeIfNeeded(
                                    AppMotion.imageWidth(context, 96),
                                    null,
                                    NetworkImage(
                                      _avatarUrlController.text.trim(),
                                    ),
                                  )
                                : null,
                            child: _avatarUrlController.text.trim().isEmpty
                                ? Text(
                                    widget.currentUser.fullName.isNotEmpty
                                        ? widget.currentUser.fullName[0]
                                              .toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Full Name
                    Text(
                      'Họ và tên *',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      maxLength: 150,
                      decoration: InputDecoration(
                        hintText: 'Nhập họ và tên hiển thị',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest.withAlpha(
                          100,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Họ và tên không được để trống.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    Text(
                      'Tiểu sử',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Chia sẻ ngắn về bản thân bạn…',
                        filled: true,
                        fillColor: colors.surfaceContainerHighest.withAlpha(
                          100,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Avatar URL
                    Text(
                      'Đường dẫn ảnh đại diện (URL)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _avatarUrlController,
                      decoration: InputDecoration(
                        hintText: 'https://... hoặc /uploads/...',
                        prefixIcon: const Icon(Icons.image_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_rounded),
                          tooltip: 'Xem trước ảnh',
                          onPressed: () => setState(() {}),
                        ),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest.withAlpha(
                          100,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),

                    // Error Display
                    if (_error != null) ...[
                      ErrorNotice(message: _error!),
                      const SizedBox(height: 16),
                    ],

                    // Save Button
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: BusyIcon(busy: _busy, icon: Icons.save_rounded),
                        label: Text(
                          _busy ? 'Đang lưu…' : 'Lưu thay đổi',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _busy ? null : _saveProfile,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
