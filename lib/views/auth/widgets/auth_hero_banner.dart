import 'package:flutter/material.dart';

class AuthHeroBanner extends StatelessWidget {
  const AuthHeroBanner({super.key, required this.isRegistration});

  final bool isRegistration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
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
            isRegistration
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
    );
  }
}
