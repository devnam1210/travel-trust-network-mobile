import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/auth_controller.dart';
import 'auth_actions.dart';
import 'auth_form.dart';
import 'auth_header.dart';
import 'auth_hero_banner.dart';
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

  void _clearError() {
    ref.read(authControllerProvider.notifier).clearError();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập họ và tên.';
    }
    if (value.trim().length > 150) return 'Tên tối đa 150 ký tự.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (email.length > 50 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Email không hợp lệ.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (!widget.isRegistration && password.length > 32) {
      return 'Mật khẩu tối đa 32 ký tự.';
    }
    if (widget.isRegistration &&
        (password.length < 8 || password.length > 32)) {
      return 'Mật khẩu cần từ 8 đến 32 ký tự.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    return value == _password.text ? null : 'Mật khẩu xác nhận không khớp.';
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
                  const AuthHeader(),
                  const SizedBox(height: 32),
                  AuthHeroBanner(isRegistration: widget.isRegistration),
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
                  AuthForm(
                    formKey: _formKey,
                    isRegistration: widget.isRegistration,
                    isBusy: auth.isBusy,
                    showPassword: _showPassword,
                    nameController: _name,
                    emailController: _email,
                    passwordController: _password,
                    confirmPasswordController: _confirmPassword,
                    onChanged: _clearError,
                    onTogglePassword: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                    onSubmit: _submit,
                    nameValidator: _validateName,
                    emailValidator: _validateEmail,
                    passwordValidator: _validatePassword,
                    confirmPasswordValidator: _validateConfirmPassword,
                  ),
                  const SizedBox(height: 22),
                  AuthActions(
                    isRegistration: widget.isRegistration,
                    isBusy: auth.isBusy,
                    onSubmit: _submit,
                    onGoogleSignIn: ref
                        .read(authControllerProvider.notifier)
                        .signInWithGoogle,
                    onSwitchMode: widget.onSwitchMode,
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
