import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../shared/motion/app_motion.dart';
import '../../shared/widgets/motion_feedback.dart';
import '../auth/auth_controller.dart';
import '../friends/friends_screen.dart';
import '../messages/inbox_screen.dart';
import '../notifications/notifications_screen.dart';
import 'locket_card.dart';
import 'locket_model.dart';
import 'locket_service.dart';
import 'send_locket_screen.dart';

class LocketFeedScreen extends ConsumerStatefulWidget {
  const LocketFeedScreen({super.key});
  @override
  ConsumerState<LocketFeedScreen> createState() => _LocketFeedScreenState();
}

class _LocketFeedScreenState extends ConsumerState<LocketFeedScreen> {
  int _tab = 0, _page = 0, _generation = 0;
  bool _loadingMore = false, _hasMore = true;
  final _extra = <LocketSignal>[];
  String? _pageError;
  bool _friendsVisited = false;

  void _reset() {
    _generation++;
    _page = 0;
    _extra.clear();
    _pageError = null;
    _hasMore = true;
    _loadingMore = false;
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    setState(() {
      _loadingMore = false;
      _pageError = null;
    });
    try {
      ref.invalidate(locketFeedProvider);
      await ref.read(locketFeedProvider.future);
      if (mounted && generation == _generation) setState(_reset);
    } catch (_) {
      /* Provider displays the refresh failure. */
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final version = _generation;
    setState(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final service = ref.read(locketServiceProvider);
      final result = await service.getFeed(page: _page + 1);
      if (!mounted || version != _generation) return;
      setState(() {
        _extra.addAll(result);
        _page++;
        _hasMore = result.length == LocketService.pageSize;
      });
    } catch (e) {
      if (mounted && version == _generation) {
        setState(() => _pageError = _message(e));
      }
    } finally {
      if (mounted && version == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  String _message(Object e) =>
      e is ApiException ? e.message : 'Không tải được Locket.';

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider.select((a) => a.user?.id), (
      previous,
      next,
    ) {
      if (previous != next) setState(_reset);
    });
    final feed = ref.watch(locketFeedProvider);
    ref.listen(locketFeedProvider, (previous, next) {
      if (next.hasError && next.hasValue && previous?.isLoading == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_message(next.error!)),
            action: SnackBarAction(label: 'Thử lại', onPressed: _refresh),
          ),
        );
      }
    });
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Locket'),
          actions: [
            const NotificationsButton(),
            IconButton(
              tooltip: 'Tin nhắn',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const InboxScreen())),
            ),
          ],
          bottom: TabBar(
            onTap: (index) {
              if (index != _tab) {
                setState(() {
                  _tab = index;
                  if (index == 1) _friendsVisited = true;
                });
              }
            },
            tabs: const [
              Tab(text: 'Bảng tin'),
              Tab(text: 'Bạn bè'),
            ],
          ),
        ),
        floatingActionButton: _tab == 0
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final sent = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const SendLocketScreen()),
                  );
                  if (mounted && sent == true) await _refresh();
                },
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text('Gửi ảnh'),
              )
            : null,
        body: IndexedStack(
          index: _tab,
          children: [
            AnimatedSlide(
              offset: _tab == 0 || AppMotion.reduced(context)
                  ? Offset.zero
                  : const Offset(0, 0.012),
              duration: AppMotion.duration(context, AppMotion.feedback),
              curve: AppMotion.curve,
              child: TickerMode(
                enabled: _tab == 0,
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      feed.when(
                        skipLoadingOnRefresh: true,
                        skipError: true,
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48),
                            const SizedBox(height: 12),
                            Text(_message(e), textAlign: TextAlign.center),
                            TextButton(
                              onPressed: _refresh,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                        data: (initial) {
                          final items = <String, LocketSignal>{
                            for (final s in [...initial, ..._extra]) s.id: s,
                          }.values.toList();
                          if (items.isEmpty) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(48),
                              children: const [
                                Icon(Icons.photo_library_outlined, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Chưa có ảnh nào.',
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  'Kết bạn để chia sẻ những khoảnh khắc riêng tư.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }
                          final more =
                              initial.length == LocketService.pageSize &&
                              _hasMore;
                          final itemIndices = {
                            for (var i = 0; i < items.length; i++)
                              items[i].id: i,
                          };
                          return ListView.builder(
                            key: PageStorageKey(
                              'locket-feed-${ref.read(authControllerProvider).user?.id}',
                            ),
                            findChildIndexCallback: (key) {
                              return key is ValueKey<String>
                                  ? itemIndices[key.value]
                                  : null;
                            },
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            itemCount: items.length + (more ? 1 : 0),
                            itemBuilder: (_, i) => i < items.length
                                ? LocketCard(
                                    key: ValueKey(items[i].id),
                                    signal: items[i],
                                  )
                                : Column(
                                    children: [
                                      if (_pageError != null) Text(_pageError!),
                                      TextButton(
                                        onPressed: _loadingMore
                                            ? null
                                            : _loadMore,
                                        child: Text(
                                          _loadingMore
                                              ? 'Đang tải…'
                                              : 'Xem thêm',
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
                      if (feed.isRefreshing)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LoadingLine(visible: true),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSlide(
              offset: _tab == 1 || AppMotion.reduced(context)
                  ? Offset.zero
                  : const Offset(0, 0.012),
              duration: AppMotion.duration(context, AppMotion.feedback),
              curve: AppMotion.curve,
              child: TickerMode(
                enabled: _tab == 1,
                child: _friendsVisited
                    ? const FriendsScreen(embedded: true)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
