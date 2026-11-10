import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../auth/auth_controller.dart';
import 'message_model.dart';
import 'message_service.dart';
import 'message_bubble.dart';
import '../notifications/notification_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.peerId, this.conversationId, this.quote})
    : assert((peerId == null) != (conversationId == null));
  final String? peerId, conversationId;
  final PhotoQuote? quote;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <int, ChatMessage>{};
  Conversation? _conversation;
  int? _receivedCursor;
  int _lastMarkedRead = 0;
  bool _markingRead = false;
  PhotoQuote? _quote;
  Timer? _poll;
  bool _loading = true,
      _syncing = false,
      _sending = false,
      _older = false,
      _hasOlder = false,
      _uncertain = false;
  String? _error, _sendError, _syncError, _clientId;
  late final String? _userId;
  late final String? _token;
  bool _foreground = true;

  bool get _active =>
      mounted &&
      ref.read(authControllerProvider).user?.id == _userId &&
      ref.read(apiServiceProvider).accessToken == _token;

  @override
  void initState() {
    super.initState();
    _userId = ref.read(authControllerProvider).user?.id;
    _token = ref.read(apiServiceProvider).accessToken;
    _quote = widget.quote;
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_queueRead);
    unawaited(_load());
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_active && _foreground && ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _active) unawaited(_refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_active) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(messageServiceProvider);
      final c = widget.conversationId != null
          ? await service.get(widget.conversationId!)
          : await service.open(widget.peerId!);
      if (!_active) return;
      final items = await service.history(c.id);
      if (!_active) return;
      setState(() {
        _conversation = c;
        _messages.addEntries(items.map((m) => MapEntry(m.id, m)));
        _hasOlder = items.length == MessageService.pageSize;
        _receivedCursor = items.isEmpty
            ? null
            : items.map((m) => m.id).reduce((a, b) => a > b ? a : b);
      });
    } catch (e) {
      if (_active) setState(() => _error = _message(e));
    } finally {
      if (_active) setState(() => _loading = false);
      _queueRead();
    }
  }

  Future<void> _refresh() async {
    if (!_active || _loading || _syncing || _conversation == null) return;
    _syncing = true;
    try {
      final service = ref.read(messageServiceProvider);
      final c = await service.get(_conversation!.id);
      if (!_active) return;
      // Track server sync separately: an outgoing message must not skip an unseen incoming reply.
      final newest = _receivedCursor;
      final items = await service.history(c.id, after: newest);
      if (_active) {
        setState(() {
          _conversation = c;
          _syncError = null;
          if (newest == null) {
            _hasOlder = items.length == MessageService.pageSize;
          }
          if (items.isNotEmpty) {
            _receivedCursor = items
                .map((m) => m.id)
                .reduce((a, b) => a > b ? a : b);
          }
          _messages.addEntries(items.map((m) => MapEntry(m.id, m)));
        });
      }
    } catch (e) {
      if (_active) setState(() => _syncError = _message(e));
    } finally {
      _syncing = false;
      _queueRead();
    }
  }

  void _queueRead() {
    if (!_active) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_active) unawaited(_markVisibleRead());
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _markVisibleRead() async {
    final cursor = _receivedCursor;
    if (!_active ||
        !_foreground ||
        _loading ||
        _markingRead ||
        ModalRoute.of(context)?.isCurrent != true ||
        !_scroll.hasClients ||
        _scroll.offset > 64 ||
        cursor == null ||
        cursor <= _lastMarkedRead ||
        _conversation == null) {
      return;
    }
    _markingRead = true;
    var succeeded = false;
    try {
      await ref
          .read(messageServiceProvider)
          .markRead(_conversation!.id, cursor);
      if (!_active) return;
      _lastMarkedRead = cursor;
      succeeded = true;
      ref.invalidate(inboxProvider);
      ref.invalidate(unreadMessagesProvider);
      ref.invalidate(unreadNotificationsProvider);
    } catch (_) {
      // Keep the unread count; a later foreground sync retries the acknowledgement.
    } finally {
      _markingRead = false;
      if (succeeded && _receivedCursor != cursor) _queueRead();
    }
  }

  Future<void> _loadOlder() async {
    if (!_active || _older || !_hasOlder || _messages.isEmpty) return;
    setState(() => _older = true);
    try {
      final before = _messages.keys.reduce((a, b) => a < b ? a : b);
      final items = await ref
          .read(messageServiceProvider)
          .history(_conversation!.id, before: before);
      if (_active) {
        setState(() {
          _messages.addEntries(items.map((m) => MapEntry(m.id, m)));
          _hasOlder = items.length == MessageService.pageSize;
          _syncError = null;
        });
      }
    } catch (e) {
      if (_active) setState(() => _syncError = _message(e));
    } finally {
      if (_active) setState(() => _older = false);
    }
  }

  Future<void> _send() async {
    final text = _draft.text.trim();
    if (!_active ||
        _sending ||
        text.isEmpty ||
        _conversation == null ||
        (!_conversation!.canSend && !_uncertain)) {
      return;
    }
    _clientId ??= MessageService.newClientId();
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final sent = await ref
          .read(messageServiceProvider)
          .send(
            _conversation!.id,
            clientId: _clientId!,
            body: text,
            quotedSignalId: _quote?.signalId,
          );
      if (!_active) return;
      setState(() {
        _messages[sent.id] = sent;
        _draft.clear();
        _quote = null;
        _clientId = null;
        _uncertain = false;
      });
      ref.invalidate(inboxProvider);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (e) {
      if (_active) {
        setState(() {
          _uncertain =
              e is! ApiException || e.isUncertain || (e.statusCode ?? 0) >= 500;
          if (!_uncertain) _clientId = null;
          _sendError = _uncertain
              ? 'Chưa xác nhận được tin nhắn. Nhấn gửi lại để thử cùng tin này.'
              : _message(e);
        });
      }
    } finally {
      if (_active) setState(() => _sending = false);
    }
  }

  String _message(Object e) => e is ApiException
      ? e.message
      : 'Không tải được tin nhắn. Vui lòng thử lại.';
  @override
  Widget build(BuildContext context) {
    ref.listen(notificationEventProvider, (_, event) {
      if (event?.isMessage == true &&
          event?.targetId == _conversation?.id &&
          _foreground &&
          _active) {
        unawaited(_refresh());
      }
    });
    final current = ref.watch(authControllerProvider.select((a) => a.user?.id));
    if (current != _userId || current == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tin nhắn')),
        body: const Center(child: Text('Vui lòng đăng nhập lại.')),
      );
    }
    final ordered = _messages.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    final editable =
        !_sending && !_uncertain && (_conversation?.canSend ?? false);
    return Scaffold(
      appBar: AppBar(
        title: Text(_conversation?.peerName ?? 'Tin nhắn'),
        actions: [
          IconButton(
            tooltip: 'Làm mới tin nhắn',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          : Column(
              children: [
                if (_syncError != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_syncError!),
                  ),
                Expanded(
                  child: ordered.isEmpty
                      ? const Center(child: Text('Chưa có tin nhắn.'))
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          itemCount: ordered.length + (_hasOlder ? 1 : 0),
                          itemBuilder: (_, i) => i == ordered.length
                              ? TextButton(
                                  onPressed: _older ? null : _loadOlder,
                                  child: Text(
                                    _older ? 'Đang tải…' : 'Tin nhắn cũ hơn',
                                  ),
                                )
                              : MessageBubble(
                                  key: ValueKey(ordered[i].id),
                                  message: ordered[i],
                                  isMine: ordered[i].senderId == current,
                                ),
                        ),
                ),
                if (!(_conversation?.canSend ?? false))
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Hai người cần kết bạn để gửi tin nhắn mới.'),
                  ),
                if (_sendError != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_sendError!),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_quote != null)
                          PhotoQuotePreview(
                            quote: _quote!,
                            onRemove: editable
                                ? () => setState(() => _quote = null)
                                : null,
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _draft,
                                enabled: editable,
                                maxLength: 1000,
                                minLines: 1,
                                maxLines: 4,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Nhắn tin…',
                                  counterText: '',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: _uncertain
                                  ? 'Gửi lại tin nhắn'
                                  : 'Gửi tin nhắn',
                              onPressed:
                                  _sending ||
                                      _draft.text.trim().isEmpty ||
                                      (!editable && !_uncertain)
                                  ? null
                                  : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
