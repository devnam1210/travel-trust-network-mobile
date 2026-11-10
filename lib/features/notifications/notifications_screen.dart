import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../auth/auth_controller.dart';
import 'notification_host.dart';
import 'notification_model.dart';
import 'notification_service.dart';

class NotificationsButton extends ConsumerWidget {
  const NotificationsButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsProvider).asData?.value ?? 0;
    return IconButton(
      tooltip: 'Thông báo',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      ),
    );
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _items = <String, AppNotification>{};
  final _read = <String>{};
  bool _loading = true, _more = false, _hasMore = true;
  String? _error, _before;
  int _generation = 0;
  late final String? _user, _jwt;
  bool get _active =>
      mounted &&
      ref.read(authControllerProvider).user?.id == _user &&
      ref.read(apiServiceProvider).accessToken == _jwt;

  @override
  void initState() {
    super.initState();
    _user = ref.read(authControllerProvider).user?.id;
    _jwt = ref.read(apiServiceProvider).accessToken;
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (!_active || (more && (_more || !_hasMore || _loading))) return;
    final generation = more ? _generation : ++_generation;
    setState(() {
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _more = false;
      }
      _error = null;
    });
    try {
      final items = await ref
          .read(notificationServiceProvider)
          .history(before: more ? _before : null);
      if (!_active || generation != _generation) return;
      setState(() {
        if (!more) _items.clear();
        _items.addEntries(items.map((n) => MapEntry(n.id, n)));
        _before = items.isEmpty ? _before : items.last.id;
        _hasMore = items.length == NotificationService.pageSize;
      });
      ref.invalidate(unreadNotificationsProvider);
    } catch (e) {
      if (_active && generation == _generation) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Không tải được thông báo.',
        );
      }
    } finally {
      if (_active && generation == _generation) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    final d = value.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} ${pad(d.hour)}:${pad(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider.select((a) => a.user?.id));
    ref.listen(notificationEventProvider, (_, event) {
      if (event != null && event.recipientId == _user && _active) {
        setState(() => _items[event.id] = event);
      }
    });
    final items = _items.values.toList()
      ..sort((a, b) => int.parse(b.id).compareTo(int.parse(a.id)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            tooltip: 'Làm mới thông báo',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: user == null || user != _user
          ? const Center(child: Text('Vui lòng đăng nhập lại.'))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(_error!),
                          TextButton(
                            onPressed: () => _load(),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  if (_items.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('Chưa có thông báo.')),
                    ),
                  for (final n in items)
                    ListTile(
                      leading: Icon(
                        n.isMessage
                            ? Icons.chat_bubble_outline
                            : Icons.person_add_alt_1,
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight: n.readAt == null && !_read.contains(n.id)
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text('${n.body}\n${_date(n.createdAt)}'),
                      isThreeLine: true,
                      trailing: n.readAt == null && !_read.contains(n.id)
                          ? const Icon(Icons.circle, size: 8)
                          : null,
                      onTap: () {
                        setState(() => _read.add(n.id));
                        openNotification(ref, n);
                      },
                    ),
                  if (_hasMore && _items.isNotEmpty)
                    TextButton(
                      onPressed: _more ? null : () => _load(more: true),
                      child: Text(_more ? 'Đang tải…' : 'Thông báo cũ hơn'),
                    ),
                ],
              ),
            ),
    );
  }
}
