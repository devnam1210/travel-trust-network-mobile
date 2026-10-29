import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/auth_controller.dart';
import 'error_notice.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    required this.isRegistration,
    required this.onSwitchMode,
  });

  final bool isRegistration;
  final VoidCallback onSwitchMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authControllerProvider).isBusy ||
        !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final controller = ref.read(authControllerProvider.notifier);
    if (widget.isRegistration) {
      await controller.register(
        _email.text.trim(),
        _name.text.trim(),
        _password.text,
      );
    } else {
      await controller.login(_email.text.trim(), _password.text);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (email.length > 150 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Email không hợp lệ.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (!widget.isRegistration && password.length > 128) {
      return 'Mật khẩu tối đa 128 ký tự.';
    }
    if (widget.isRegistration &&
        (password.length < 8 || password.length > 128)) {
      return 'Mật khẩu cần từ 8 đến 128 ký tự.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.explore_rounded,
                          color: colors.onPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Travel Trust\nNetwork',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          widget.isRegistration
                              ? Icons.travel_explore_rounded
                              : Icons.landscape_rounded,
                          size: 58,
                          color: colors.onPrimaryContainer,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Hành trình thật.\nNiềm tin thật.',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Khám phá điểm đến và chia sẻ những trải nghiệm đáng tin cậy.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    widget.isRegistration
                        ? 'Tạo tài khoản'
                        : 'Chào mừng trở lại',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isRegistration
                        ? 'Đăng ký bằng email Gmail và đặt mật khẩu cho Travel Trust Network.'
                        : 'Đăng nhập bằng email và mật khẩu của tài khoản Travel Trust Network.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (auth.error != null) ...[
                    ErrorNotice(message: auth.error!),
                    const SizedBox(height: 16),
                  ],
                  AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (widget.isRegistration) ...[
                            TextFormField(
                              controller: _name,
                              enabled: !auth.isBusy,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Họ và tên',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => ref
                                  .read(authControllerProvider.notifier)
                                  .clearError(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vui lòng nhập họ và tên.';
                                }
                                if (value.trim().length > 150) {
                                  return 'Tên tối đa 150 ký tự.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _email,
                            enabled: !auth.isBusy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email (Gmail)',
                              hintText: 'ban@gmail.com',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => ref
                                .read(authControllerProvider.notifier)
                                .clearError(),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            enabled: !auth.isBusy,
                            obscureText: !_showPassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: widget.isRegistration
                                ? TextInputAction.next
                                : TextInputAction.done,
                            autofillHints: [
                              widget.isRegistration
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _showPassword
                                    ? 'Ẩn mật khẩu'
                                    : 'Hiện mật khẩu',
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => ref
                                .read(authControllerProvider.notifier)
                                .clearError(),
                            validator: _validatePassword,
                            onFieldSubmitted: (_) {
                              if (!widget.isRegistration) {
                                _submit();
                              }
                            },
                          ),
                          if (widget.isRegistration) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPassword,
                              enabled: !auth.isBusy,
                              obscureText: !_showPassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: const InputDecoration(
                                labelText: 'Xác nhận mật khẩu',
                                prefixIcon: Icon(Icons.lock_reset_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value == _password.text
                                  ? null
                                  : 'Mật khẩu xác nhận không khớp.',
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: auth.isBusy ? null : _submit,
                    child: auth.isBusy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.isRegistration ? 'Đăng ký' : 'Đăng nhập'),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: auth.isBusy ? null : widget.onSwitchMode,
                      child: Text(
                        widget.isRegistration
                            ? 'Đã có tài khoản? Đăng nhập'
                            : 'Chưa có tài khoản? Đăng ký',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
