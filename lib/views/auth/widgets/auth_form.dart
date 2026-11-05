import 'package:flutter/material.dart';

typedef FieldValidator = String? Function(String? value);

class AuthForm extends StatelessWidget {
  const AuthForm({
    super.key,
    required this.formKey,
    required this.isRegistration,
    required this.isBusy,
    required this.showPassword,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onChanged,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.nameValidator,
    required this.emailValidator,
    required this.passwordValidator,
    required this.confirmPasswordValidator,
  });

  final GlobalKey<FormState> formKey;
  final bool isRegistration;
  final bool isBusy;
  final bool showPassword;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final FieldValidator nameValidator;
  final FieldValidator emailValidator;
  final FieldValidator passwordValidator;
  final FieldValidator confirmPasswordValidator;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          children: [
            if (isRegistration) ...[
              TextFormField(
                controller: nameController,
                enabled: !isBusy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => onChanged(),
                validator: nameValidator,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: emailController,
              enabled: !isBusy,
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
              onChanged: (_) => onChanged(),
              validator: emailValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              enabled: !isBusy,
              obscureText: !showPassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: isRegistration
                  ? TextInputAction.next
                  : TextInputAction.done,
              autofillHints: [
                isRegistration
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                  onPressed: onTogglePassword,
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
              validator: passwordValidator,
              onFieldSubmitted: (_) {
                if (!isRegistration) onSubmit();
              },
            ),
            if (isRegistration) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                enabled: !isBusy,
                obscureText: !showPassword,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: confirmPasswordValidator,
                onFieldSubmitted: (_) => onSubmit(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
