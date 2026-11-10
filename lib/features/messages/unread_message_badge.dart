import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_service.dart';

class UnreadMessageBadge extends StatelessWidget {
  const UnreadMessageBadge({super.key, required this.count, this.child});
  final int count;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    backgroundColor: Colors.red.shade700,
    textColor: Colors.white,
    label: Semantics(
      label: '$count tin nhắn chưa đọc',
      child: ExcludeSemantics(child: Text(count > 99 ? '99+' : '$count')),
    ),
    child: child,
  );
}

class MessageNavigationIcon extends ConsumerWidget {
  const MessageNavigationIcon({super.key, this.selected = false});
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(unreadMessagesProvider)
        .maybeWhen(
          skipLoadingOnReload: false,
          data: (value) => value,
          orElse: () => 0,
        );
    return UnreadMessageBadge(
      count: count,
      child: Icon(
        selected
            ? Icons.chat_bubble_rounded
            : Icons.chat_bubble_outline_rounded,
      ),
    );
  }
}
