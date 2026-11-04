import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../controllers/auth_controller.dart';
import '../models/user_model.dart';
import 'auth/widgets/error_notice.dart';
import 'visits/visit_history_screen.dart';
import 'visits/visit_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của bạn'),
        actions: [
          IconButton(
            tooltip: 'Làm mới hồ sơ',
            onPressed: state.isBusy ? null : controller.refreshProfile,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.isBusy) const LinearProgressIndicator(),
                      const SizedBox(height: 20),
                      Center(
                        child: ClipOval(
                          child: SizedBox(
                            width: 96,
                            height: 96,
                            child: user.avatarUrl?.isNotEmpty == true
                                ? Image.network(
                                    user.avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) => _avatar(colors),
                                  )
                                : _avatar(colors),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        user.fullName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      if (user.bio?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Text(user.bio!, textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 28),
                      if (state.error != null) ...[
                        ErrorNotice(message: state.error!),
                        const SizedBox(height: 20),
                      ],
                      Card.filled(
                        color: colors.primaryContainer,
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: colors.onPrimaryContainer,
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${user.trustScore}',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text('Điểm uy tín'),
                              const Divider(height: 32),
                              Text(
                                '${user.verifiedVisitCount} chuyến đi đã xác minh',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      OutlinedButton.icon(
                        onPressed: state.isBusy
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const VisitHistoryScreen(),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.history),
                        label: const Text('Lịch sử chuyến đi'),
                      ),
                      if (kDebugMode && AppConfig.testPlaceId.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: state.isBusy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const VisitScreen(
                                        placeId: AppConfig.testPlaceId,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text('Kiểm thử GPS với TEST_PLACE_ID'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Lịch sử điểm uy tín',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (user.trustScoreLogs.isEmpty)
                        const Text('Chưa có thay đổi điểm uy tín.')
                      else
                        for (final log in user.trustScoreLogs)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: colors.secondaryContainer,
                              child: Icon(
                                log.delta >= 0 ? Icons.add : Icons.remove,
                                color: colors.onSecondaryContainer,
                              ),
                            ),
                            title: Text(log.reason),
                            subtitle: Text(
                              'Điểm sau thay đổi: ${log.newScore}',
                            ),
                            trailing: Text(
                              '${log.delta >= 0 ? '+' : ''}${log.delta}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: log.delta >= 0
                                    ? colors.primary
                                    : colors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        onPressed: state.isBusy ? null : controller.logout,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(ColorScheme colors) => ColoredBox(
    color: colors.secondaryContainer,
    child: Icon(
      Icons.person_rounded,
      size: 52,
      color: colors.onSecondaryContainer,
    ),
  );
}
