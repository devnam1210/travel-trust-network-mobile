import 'package:flutter/material.dart';

import '../../shared/motion/app_motion.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../auth/auth_controller.dart';
import '../locket/locket_card.dart';
import '../locket/locket_model.dart';
import '../locket/locket_service.dart';
import '../messages/chat_screen.dart';
import 'friend_model.dart';
import 'friend_service.dart';

class FriendProfileScreen extends ConsumerStatefulWidget {
  const FriendProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<FriendProfileScreen> createState() =>
      _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  FriendUser? _person;
  final _posts = <LocketSignal>[];
  bool _loading = true, _loadingMore = false, _hasMore = false;
  int _page = 0, _generation = 0;
  String? _error, _pageError;
  late final String? _viewer;
  late final int _token;

  bool _active(int generation) =>
      mounted &&
      generation == _generation &&
      ref.read(authControllerProvider).user?.id == _viewer &&
      ref.read(apiServiceProvider).sessionVersion == _token;

  @override
  void initState() {
    super.initState();
    _viewer = ref.read(authControllerProvider).user?.id;
    _token = ref.read(apiServiceProvider).sessionVersion;
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (!_active(generation) || _viewer == null) return;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _pageError = null;
    });
    try {
      final person = await ref
          .read(friendServiceProvider)
          .profile(widget.userId);
      if (!_active(generation)) return;
      final posts = await ref
          .read(locketServiceProvider)
          .getUserPosts(widget.userId);
      if (!_active(generation)) return;
      setState(() {
        _person = person;
        _posts
          ..clear()
          ..addAll(posts);
        _page = 0;
        _hasMore = posts.length == LocketService.pageSize;
      });
    } catch (e) {
      if (_active(generation)) setState(() => _error = _message(e));
    } finally {
      if (_active(generation)) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final next = await ref
          .read(locketServiceProvider)
          .getUserPosts(widget.userId, page: _page + 1);
      if (!_active(generation)) return;
      setState(() {
        final existing = _posts.map((p) => p.id).toSet();
        _posts.addAll(next.where((p) => existing.add(p.id)));
        _page++;
        _hasMore = next.length == LocketService.pageSize;
      });
    } catch (e) {
      if (_active(generation)) setState(() => _pageError = _message(e));
    } finally {
      if (_active(generation)) setState(() => _loadingMore = false);
    }
  }

  String _message(Object e) =>
      e is ApiException ? e.message : 'Không tải được hồ sơ. Vui lòng thử lại.';

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(authControllerProvider.select((a) => a.user?.id));
    final signedIn = current != null && current == _viewer;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'Làm mới hồ sơ',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: !signedIn
          ? const Center(child: Text('Vui lòng đăng nhập lại.'))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    )
                  : CustomScrollView(
                      key: PageStorageKey('friend-profile-${widget.userId}'),
                      slivers: [
                        SliverToBoxAdapter(child: _header(_person!)),
                        if (_posts.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'Chưa có ảnh Locket nào để hiển thị.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          sliver: SliverList.builder(
                            itemCount: _posts.length,
                            itemBuilder: (_, i) => LocketCard(
                              key: ValueKey(_posts[i].id),
                              signal: _posts[i],
                              showProfileLink: false,
                            ),
                          ),
                        ),
                        if (_hasMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  if (_pageError != null) Text(_pageError!),
                                  TextButton(
                                    onPressed: _loadingMore ? null : _loadMore,
                                    child: Text(
                                      _loadingMore
                                          ? 'Đang tải…'
                                          : 'Xem ảnh cũ hơn',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
            ),
    );
  }

  Widget _header(FriendUser person) {
    final self = person.id == _viewer;
    final relationship = switch (person.relationship) {
      'FRIEND' => 'Bạn bè',
      'INCOMING' => 'Đã nhận lời mời kết bạn',
      'OUTGOING' => 'Đã gửi lời mời kết bạn',
      _ => 'Chưa kết bạn',
    };
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            child: person.avatarUrl?.isNotEmpty == true
                ? ClipOval(
                    child: Image.network(
                      person.avatarUrl!,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      cacheWidth: AppMotion.imageWidth(context, 84),
                      frameBuilder: AppMotion.imageFrame,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.person_outline, size: 42),
                    ),
                  )
                : const Icon(Icons.person_outline, size: 42),
          ),
          const SizedBox(height: 12),
          Text(
            person.fullName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (person.username != null) Text('@${person.username}'),
          const SizedBox(height: 6),
          Text(self ? 'Trang của bạn' : relationship),
          if (!self && person.relationship == 'FRIEND')
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(peerId: person.id),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Nhắn tin'),
            ),
          const Divider(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              self ? 'Ảnh đã đăng' : 'Ảnh đã chia sẻ với bạn',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Mới nhất trước · ngày và giờ bên dưới tên người đăng'),
          ),
        ],
      ),
    );
  }
}
