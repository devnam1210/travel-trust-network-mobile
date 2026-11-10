import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../friends/friend_service.dart';

/// Return a current friend; opening/sending still uses the authenticated chat API.
class NewConversationSheet extends ConsumerWidget {
  const NewConversationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider('friends'));
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Nhắn tin với bạn bè',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: friends.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error is ApiException
                            ? error.message
                            : 'Không tải được danh sách bạn bè.',
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(friendsProvider('friends')),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
                data: (people) => people.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Bạn cần kết bạn để bắt đầu nhắn tin.'),
                        ),
                      )
                    : ListView.builder(
                        itemCount: people.length,
                        itemBuilder: (_, index) {
                          final friend = people[index];
                          return ListTile(
                            key: ValueKey(friend.id),
                            leading: CircleAvatar(
                              child: Text(
                                friend.fullName.isEmpty
                                    ? '?'
                                    : friend.fullName.characters.first,
                              ),
                            ),
                            title: Text(friend.fullName),
                            trailing: const Icon(
                              Icons.chat_bubble_outline_rounded,
                            ),
                            onTap: () => Navigator.of(context).pop(friend),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
