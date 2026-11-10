import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../shared/widgets/error_notice.dart';
import '../../shared/widgets/motion_feedback.dart';
import '../../shared/motion/app_motion.dart';
import '../auth/auth_controller.dart';
import 'friend_model.dart';
import 'friend_service.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({
    super.key,
    this.embedded = false,
    this.initialKind = 'friends',
  });
  final bool embedded;
  final String initialKind;
  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _search = TextEditingController();
  final _username = TextEditingController();
  final _busy = <String>{};
  List<FriendUser>? _results;
  bool _searching = false;
  int _searchVersion = 0;
  Timer? _searchDebounce;
  String? _error;
  String _listKind = 'friends';

  @override
  void initState() {
    super.initState();
    _listKind = widget.initialKind;
    _username.text = ref.read(authControllerProvider).user?.username ?? '';
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    _searchDebounce?.cancel();
    final version = ++_searchVersion;
    final query = _search.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _searching = false;
        _error = null;
      });
      return;
    }
    final user = ref.read(authControllerProvider).user?.id;
    if (user == null) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref.read(friendServiceProvider).search(query);
      if (mounted &&
          version == _searchVersion &&
          ref.read(authControllerProvider).user?.id == user) {
        setState(() => _results = results);
      }
    } catch (e) {
      if (mounted && version == _searchVersion) {
        setState(() => _error = _message(e));
      }
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() => _searching = false);
      }
    }
  }

  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    // Invalidate an older response as soon as the text changes, before the next request starts.
    _searchVersion++;
    setState(() {
      _results = null;
      _searching = false;
      _error = null;
    });
    if (value.trim().isNotEmpty) {
      _searchDebounce = Timer(const Duration(milliseconds: 350), _find);
    }
  }

  void _refreshLists() {
    for (final kind in ['friends', 'incoming', 'outgoing']) {
      ref.invalidate(friendsProvider(kind));
    }
  }

  Future<void> _act(String key, Future<void> Function() action) async {
    if (_busy.contains(key)) return;
    setState(() {
      _busy.add(key);
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      _refreshLists();
      if (_results != null) await _find();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _saveUsername() => _act('username', () async {
    final name = await ref
        .read(friendServiceProvider)
        .updateUsername(_username.text);
    if (!mounted) return;
    _username.text = name;
    await ref.read(authControllerProvider.notifier).refreshProfile();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã cập nhật username')));
    }
  });

  String _message(Object e) => e is ApiException
      ? e.message
      : 'Không thể cập nhật bạn bè. Vui lòng thử lại.';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider.select((a) => a.user));
    if (user == null) {
      if (widget.embedded) {
        return const Center(child: Text('Vui lòng đăng nhập lại.'));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Bạn bè')),
        body: const Center(child: Text('Vui lòng đăng nhập lại.')),
      );
    }
    final searching = _search.text.trim().isNotEmpty;
    final content = Column(
      children: [
        _searchField(),
        if (!widget.embedded)
          ExpansionTile(
            title: Text(
              user.username == null
                  ? 'Username (không bắt buộc)'
                  : '@${user.username}',
            ),
            subtitle: user.username == null
                ? const Text('Bạn bè có thể tìm bạn bằng họ tên.')
                : null,
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              TextField(
                controller: _username,
                maxLength: 30,
                enabled: !_busy.contains('username'),
                decoration: const InputDecoration(
                  labelText: 'Username',
                  helperText: '3–30 chữ cái, số hoặc dấu gạch dưới',
                ),
              ),
              TextButton(
                onPressed: _busy.contains('username') ? null : _saveUsername,
                child: const Text('Lưu username'),
              ),
            ],
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: ErrorNotice(message: _error!),
          ),
        LoadingLine(visible: _searching),
        if (!searching)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final entry in const {
                  'friends': 'Bạn bè',
                  'incoming': 'Lời mời nhận',
                  'outgoing': 'Lời mời gửi',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _listKind == entry.key,
                    onSelected: (_) => setState(() => _listKind = entry.key),
                  ),
              ],
            ),
          ),
        Expanded(child: searching ? _searchResults() : _listTab(_listKind)),
      ],
    );
    return widget.embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: const Text('Bạn bè')),
            body: content,
          );
  }

  Widget _searchResults() {
    if (_results != null) {
      return _people(
        _results!,
        emptyMessage: 'Không tìm thấy người dùng phù hợp.',
      );
    }
    if (_error != null && !_searching) {
      return Center(
        child: TextButton(onPressed: _find, child: const Text('Thử lại')),
      );
    }
    return const Center(child: Text('Đang tìm bạn…'));
  }

  Widget _searchField() => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: _searchChanged,
            onSubmitted: (_) => _find(),
            textInputAction: TextInputAction.search,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'Tìm bạn theo họ và tên',
              counterText: '',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _searchChanged('');
                      },
                    ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Tìm kiếm',
          onPressed: _searching ? null : _find,
          icon: const Icon(Icons.arrow_forward),
        ),
      ],
    ),
  );

  Widget _listTab(String kind) {
    final people = ref.watch(friendsProvider(kind));
    return RefreshIndicator(
      onRefresh: () async {
        try {
          ref.invalidate(friendsProvider(kind));
          await ref.read(friendsProvider(kind).future);
        } catch (_) {
          /* Render provider error below. */
        }
      },
      child: people.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_message(e)),
            ),
            TextButton(
              onPressed: () => ref.invalidate(friendsProvider(kind)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
        data: (people) => _people(people),
      ),
    );
  }

  Widget _people(
    List<FriendUser> people, {
    String emptyMessage = 'Chưa có người dùng nào.',
  }) => people.isEmpty
      ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(emptyMessage, textAlign: TextAlign.center),
            ),
          ],
        )
      : ListView.builder(
          key: PageStorageKey('friends-$_listKind-${_search.text.trim()}'),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: people.length,
          itemBuilder: (_, i) {
            final friend = people[i];
            return ListTile(
              key: ValueKey(friend.id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FriendProfileScreen(userId: friend.id),
                ),
              ),
              leading: CircleAvatar(
                child: Text(
                  friend.fullName.isEmpty
                      ? '?'
                      : friend.fullName.characters.first,
                ),
              ),
              title: Text(friend.fullName),
              subtitle: friend.username == null
                  ? null
                  : Text('@${friend.username}'),
              trailing: AnimatedSize(
                duration: AppMotion.duration(context, AppMotion.expand),
                curve: AppMotion.curve,
                alignment: Alignment.centerRight,
                child: IntrinsicWidth(
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      IgnorePointer(
                        ignoring: _busy.contains(friend.id),
                        child: AnimatedOpacity(
                          opacity: _busy.contains(friend.id) ? 0 : 1,
                          duration: AppMotion.duration(
                            context,
                            AppMotion.feedback,
                          ),
                          child: MotionSwitcher(
                            alignment: Alignment.centerRight,
                            child: KeyedSubtree(
                              key: ValueKey(friend.relationship),
                              child: _actions(friend),
                            ),
                          ),
                        ),
                      ),
                      if (_busy.contains(friend.id))
                        const Positioned.fill(
                          child: Center(
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

  Widget _actions(FriendUser friend) {
    final service = ref.read(friendServiceProvider);
    final id = friend.relationshipId;
    Widget button(String title, VoidCallback action) =>
        TextButton(onPressed: action, child: Text(title));
    switch (friend.relationship) {
      case 'INCOMING':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button('Nhận', () => _act(friend.id, () => service.accept(id!))),
            button(
              'Từ chối',
              () => _act(friend.id, () => service.remove(id!, 'reject')),
            ),
          ],
        );
      case 'OUTGOING':
        return button(
          'Hủy lời mời',
          () => _act(friend.id, () => service.remove(id!, 'cancel')),
        );
      case 'FRIEND':
        return button(
          'Hủy kết bạn',
          () => _act(friend.id, () => service.remove(id!, 'unfriend')),
        );
      default:
        return button(
          'Kết bạn',
          () => _act(friend.id, () => service.request(friend.id)),
        );
    }
  }
}
