import 'package:flutter/material.dart';

class AuthActions extends StatelessWidget {
  const AuthActions({
    super.key,
    required this.isRegistration,
    required this.isBusy,
    required this.onSubmit,
    required this.onGoogleSignIn,
    required this.onSwitchMode,
  });

  final bool isRegistration;
  final bool isBusy;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onSwitchMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          onPressed: isBusy ? null : onSubmit,
          child: isBusy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isRegistration ? 'Đăng ký' : 'Đăng nhập'),
        ),
        const SizedBox(height: 12),
        if (!isRegistration) ...[
          OutlinedButton.icon(
            onPressed: isBusy ? null : onGoogleSignIn,
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Đăng nhập với Google'),
          ),
          const SizedBox(height: 12),
        ],
        Center(
          child: TextButton(
            onPressed: isBusy ? null : onSwitchMode,
            child: Text(
              isRegistration
                  ? 'Đã có tài khoản? Đăng nhập'
                  : 'Chưa có tài khoản? Đăng ký',
            ),
          ),
        ),
      ],
    );
  }
}
