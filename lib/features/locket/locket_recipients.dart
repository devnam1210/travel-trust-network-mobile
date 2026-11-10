import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../friends/friend_service.dart';
import '../friends/friends_screen.dart';

class LocketRecipients extends ConsumerWidget {
  const LocketRecipients({
    super.key,
    required this.allFriends,
    required this.selected,
    required this.enabled,
    required this.onAllChanged,
    required this.onSelected,
  });
  final bool allFriends;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<bool> onAllChanged;
  final void Function(String id, bool selected) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider('friends'));
    return friends.when(
      skipLoadingOnRefresh: false,
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Column(
        children: [
          Text(
            e is ApiException ? e.message : 'Không tải được danh sách bạn bè.',
          ),
          TextButton(
            onPressed: enabled
                ? () => ref.invalidate(friendsProvider('friends'))
                : null,
            child: const Text('Tải lại bạn bè'),
          ),
        ],
      ),
      data: (people) => people.isEmpty
          ? Column(
              children: [
                const Text('Bạn cần kết bạn trước khi gửi Locket.'),
                TextButton(
                  onPressed: enabled
                      ? () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FriendsScreen(),
                            ),
                          );
                          if (context.mounted) {
                            ref.invalidate(friendsProvider('friends'));
                          }
                        }
                      : null,
                  child: const Text('Tìm bạn'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gửi tất cả bạn bè'),
                  subtitle: Text('${people.length} bạn bè'),
                  value: allFriends,
                  onChanged: enabled ? onAllChanged : null,
                ),
                if (!allFriends) ...[
                  const Text('Chọn người nhận'),
                  for (final friend in people)
                    CheckboxListTile(
                      key: ValueKey('recipient-${friend.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(friend.fullName),
                      subtitle: Text('@${friend.username ?? ''}'),
                      value: selected.contains(friend.id),
                      onChanged: enabled
                          ? (value) => onSelected(friend.id, value == true)
                          : null,
                    ),
                ],
              ],
            ),
    );
  }
}
