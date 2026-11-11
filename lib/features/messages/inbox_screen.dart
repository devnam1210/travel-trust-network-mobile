import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../auth/auth_controller.dart';
import '../friends/friend_model.dart';
import '../../shared/motion/app_motion.dart';
import 'message_model.dart';
import 'message_service.dart';
import 'unread_message_badge.dart';
import 'chat_screen.dart';
import 'new_conversation_sheet.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key, this.isActive = true});
  final bool isActive;
  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen>
    with WidgetsBindingObserver {
  Timer? _poll;
  bool _foreground = true;
  final _seen = <String, Conversation>{};
  int _page = 0, _generation = 0;
  bool _loadingMore = false, _hasMore = true;
  String? _pageError;
  bool _composing = false;

  bool get _canRefresh =>
      mounted &&
      widget.isActive &&
      _foreground &&
      ref.read(authControllerProvider).user != null &&
      ModalRoute.of(context)?.isCurrent == true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_canRefresh) {
        ref.invalidate(inboxProvider);
      }
    });
  }

  @override
  void didUpdateWidget(covariant InboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_canRefresh) ref.invalidate(inboxProvider);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_canRefresh) ref.invalidate(inboxProvider);
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _seen.clear();
      _page = 0;
      _hasMore = true;
      _loadingMore = false;
      _pageError = null;
      _generation++;
    });
    ref.invalidate(inboxProvider);
    try {
      await ref.read(inboxProvider.future);
    } catch (_) {
      /* Provider shows the error. */
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final generation = _generation;
    final user = ref.read(authControllerProvider).user?.id;
    final token = ref.read(apiServiceProvider).sessionVersion;
    setState(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final items = await ref
          .read(messageServiceProvider)
          .inbox(page: _page + 1);
      if (!mounted ||
          generation != _generation ||
          user != ref.read(authControllerProvider).user?.id ||
          token != ref.read(apiServiceProvider).sessionVersion) {
        return;
      }
      setState(() {
        for (final c in items) {
          _seen[c.id] = c;
        }
        _page++;
        _hasMore = items.length == 30;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(
          () => _pageError = e is ApiException
              ? e.message
              : 'Không tải được hộp thư.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _compose() async {
    if (_composing) return;
    final user = ref.read(authControllerProvider).user?.id;
    final token = ref.read(apiServiceProvider).sessionVersion;
    if (user == null) return;
    setState(() => _composing = true);
    try {
      final friend = await showModalBottomSheet<FriendUser>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const NewConversationSheet(),
      );
      if (!mounted ||
          friend == null ||
          user != ref.read(authControllerProvider).user?.id ||
          token != ref.read(apiServiceProvider).sessionVersion) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ChatScreen(peerId: friend.id)),
      );
      if (mounted &&
          user == ref.read(authControllerProvider).user?.id &&
          token == ref.read(apiServiceProvider).sessionVersion) {
        ref.invalidate(inboxProvider);
      }
    } finally {
      if (mounted) setState(() => _composing = false);
    }
  }

  String _time(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${pad(local.hour)}:${pad(local.minute)}';
    }
    return '${pad(local.day)}/${pad(local.month)}${local.year == now.year ? '' : '/${local.year}'}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider.select((a) => a.user?.id), (
      previous,
      next,
    ) {
      if (previous != next) {
        setState(() {
          _seen.clear();
          _generation++;
          _page = 0;
          _hasMore = true;
          _loadingMore = false;
        });
      }
    });
    ref.listen(inboxProvider, (_, next) {
      final items = next.asData?.value;
      if (items != null && ref.read(authControllerProvider).user != null) {
        for (final c in items) {
          _seen[c.id] = c;
        }
      }
    });
    final user = ref.watch(authControllerProvider.select((a) => a.user?.id));
    final inbox = ref.watch(inboxProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        actions: [
          IconButton(
            tooltip: 'Nhắn tin mới',
            onPressed: user == null || _composing ? null : _compose,
            icon: const Icon(Icons.edit_square),
          ),
          IconButton(
            tooltip: 'Làm mới hộp thư',
            onPressed: user == null || inbox.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Vui lòng đăng nhập lại.'))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: inbox.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        e is ApiException
                            ? e.message
                            : 'Không tải được hộp thư.',
                      ),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
                data: (firstPage) {
                  final items =
                      {
                        ..._seen,
                        for (final c in firstPage) c.id: c,
                      }.values.toList()..sort((a, b) {
                        final time = (b.updatedAt ?? DateTime(1970)).compareTo(
                          a.updatedAt ?? DateTime(1970),
                        );
                        return time == 0 ? b.id.compareTo(a.id) : time;
                      });
                  final more = firstPage.length == 30 && _hasMore;
                  return items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'Chưa có cuộc trò chuyện.',
                              textAlign: TextAlign.center,
                            ),
                            const Text(
                              'Tin nhắn từ bạn bè sẽ xuất hiện ở đây.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _composing ? null : _compose,
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                              ),
                              label: const Text('Bắt đầu trò chuyện'),
                            ),
                          ],
                        )
                      : ListView.builder(
                          key: PageStorageKey('inbox-$user'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length + (more ? 1 : 0),
                          itemBuilder: (_, i) => i == items.length
                              ? Column(
                                  children: [
                                    if (_pageError != null) Text(_pageError!),
                                    TextButton(
                                      onPressed: _loadingMore
                                          ? null
                                          : _loadMore,
                                      child: Text(
                                        _loadingMore
                                            ? 'Đang tải…'
                                            : 'Cuộc trò chuyện cũ hơn',
                                      ),
                                    ),
                                  ],
                                )
                              : ListTile(
                                  key: ValueKey(items[i].id),
                                  leading: CircleAvatar(
                                    child:
                                        items[i].peerAvatarUrl?.isNotEmpty ==
                                            true
                                        ? ClipOval(
                                            child: Image.network(
                                              items[i].peerAvatarUrl!,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              cacheWidth: AppMotion.imageWidth(
                                                context,
                                                40,
                                              ),
                                              frameBuilder:
                                                  AppMotion.imageFrame,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.person_outline,
                                                  ),
                                            ),
                                          )
                                        : const Icon(Icons.person_outline),
                                  ),
                                  title: Text(
                                    items[i].peerName,
                                    style: items[i].unreadCount > 0
                                        ? const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          )
                                        : null,
                                  ),
                                  subtitle: Text(
                                    items[i].lastMessage ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _time(items[i].updatedAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                      if (items[i].unreadCount > 0) ...[
                                        const SizedBox(height: 4),
                                        UnreadMessageBadge(
                                          count: items[i].unreadCount,
                                        ),
                                      ],
                                    ],
                                  ),
                                  onTap: () async {
                                    final id = items[i].id;
                                    final session = ref
                                        .read(authControllerProvider)
                                        .user
                                        ?.id;
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ChatScreen(conversationId: id),
                                      ),
                                    );
                                    if (!mounted ||
                                        ref
                                                .read(authControllerProvider)
                                                .user
                                                ?.id !=
                                            session) {
                                      return;
                                    }
                                    ref.invalidate(inboxProvider);
                                    ref.invalidate(unreadMessagesProvider);
                                    try {
                                      final updated = await ref
                                          .read(messageServiceProvider)
                                          .get(id);
                                      if (mounted &&
                                          ref
                                                  .read(authControllerProvider)
                                                  .user
                                                  ?.id ==
                                              session) {
                                        setState(() => _seen[id] = updated);
                                      }
                                    } catch (_) {
                                      /* The next successful refresh recovers. */
                                    }
                                  },
                                ),
                        );
                },
              ),
            ),
    );
  }
}
