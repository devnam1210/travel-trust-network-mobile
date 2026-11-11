import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../friends/friend_service.dart';
import '../friends/friends_screen.dart';
import '../messages/chat_screen.dart';
import '../messages/message_service.dart';
import 'notification_model.dart';
import 'notification_service.dart';
import 'push_gateway.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void openNotification(WidgetRef ref, AppNotification event) {
  if (ref.read(authControllerProvider).user?.id != event.recipientId) return;
  unawaited(
    ref
        .read(notificationServiceProvider)
        .read(event.id)
        .then((_) {
          if (ref.context.mounted) ref.invalidate(unreadNotificationsProvider);
        })
        .catchError((Object _) {}),
  );
  appMessengerKey.currentState?.hideCurrentSnackBar();
  appNavigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => event.isMessage
          ? ChatScreen(conversationId: event.targetId)
          : const FriendsScreen(initialKind: 'incoming'),
    ),
  );
}

class NotificationHost extends ConsumerStatefulWidget {
  const NotificationHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends ConsumerState<NotificationHost>
    with WidgetsBindingObserver {
  CancelToken? _cancel;
  StreamSubscription<Map<String, dynamic>>? _events;
  final _pushSubscriptions = <StreamSubscription<Object?>>[];
  Timer? _retry;
  Timer? _unreadPoll;
  final _seen = <String>{};
  String? _user;
  int? _jwt;
  bool _foreground = true, _pushReady = false;
  int _generation = 0, _failures = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session(ref.read(authControllerProvider));
    });
  }

  void _session(AuthState auth) {
    final user = auth.status == AuthStatus.authenticated ? auth.user?.id : null;
    final jwt = ref.read(apiServiceProvider).sessionVersion;
    if (_user == user && _jwt == jwt) return;
    _generation++;
    _stopStream();
    _unreadPoll?.cancel();
    for (final subscription in _pushSubscriptions) {
      unawaited(subscription.cancel());
    }
    _pushSubscriptions.clear();
    _user = user;
    _jwt = jwt;
    _seen.clear();
    _failures = 0;
    appMessengerKey.currentState?.clearSnackBars();
    ref.read(notificationEventProvider.notifier).receive(null);
    ref.invalidate(unreadNotificationsProvider);
    ref.invalidate(unreadMessagesProvider);
    if (user != null && ref.read(apiServiceProvider).accessToken != null) {
      final generation = _generation;
      _unreadPoll = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_foreground && _active(generation)) {
          ref.invalidate(unreadMessagesProvider);
        }
      });
      _connect();
      unawaited(_setupPush(_generation));
    }
  }

  bool _active(int generation) =>
      mounted &&
      generation == _generation &&
      _user != null &&
      ref.read(authControllerProvider).user?.id == _user &&
      ref.read(apiServiceProvider).sessionVersion == _jwt;

  void _connect() {
    if (_user == null || !_foreground || _cancel != null) return;
    final generation = _generation;
    final cancel = _cancel = CancelToken();
    _events = ref
        .read(notificationServiceProvider)
        .events(cancel)
        .listen(
          (data) {
            if (!_active(generation)) return;
            _failures = 0;
            if (data['type'] == 'READY') {
              _refresh();
              return;
            }
            try {
              _receive(AppNotification.fromJson(data));
            } catch (_) {
              /* Invalid frame: reconnect/history recovers. */
            }
          },
          onError: (Object _) {
            if (identical(_cancel, cancel)) _reconnect(generation);
          },
          onDone: () {
            if (identical(_cancel, cancel)) _reconnect(generation);
          },
        );
  }

  void _reconnect(int generation) {
    if (!_active(generation)) return;
    final cancel = _cancel;
    _cancel = null;
    cancel?.cancel();
    _retry?.cancel();
    if (!_foreground) return;
    final seconds = (1 << _failures.clamp(0, 5));
    _failures++;
    _retry = Timer(Duration(seconds: seconds), () {
      if (_active(generation)) _connect();
    });
  }

  void _stopStream() {
    _retry?.cancel();
    _retry = null;
    final cancel = _cancel;
    _cancel = null;
    cancel?.cancel();
    unawaited(_events?.cancel());
    _events = null;
  }

  Future<void> _setupPush(int generation) async {
    final gateway = ref.read(pushGatewayProvider);
    try {
      final available = await gateway.initialize();
      if (!_active(generation) || !available) return;
      _pushReady = true;
      _pushSubscriptions.add(
        gateway.foreground.listen((event) {
          if (_active(generation) && _foreground) _receive(event);
        }, onError: (Object _) {}),
      );
      _pushSubscriptions.add(
        gateway.opened.listen((event) {
          if (_active(generation)) openNotification(ref, event);
        }, onError: (Object _) {}),
      );
      _pushSubscriptions.add(
        gateway.tokenChanges.listen((token) {
          if (_active(generation)) {
            unawaited(ref.read(pushRegistrationProvider).register(token));
          }
        }, onError: (Object _) {}),
      );
      final initial = await gateway.initial();
      if (!_active(generation)) return;
      if (initial != null) openNotification(ref, initial);
      await _registerToken(generation);
    } catch (_) {
      /* App and SSE stay usable when Firebase/network/permission is unavailable. */
    }
  }

  Future<void> _registerToken(int generation) async {
    try {
      final token = await ref.read(pushGatewayProvider).token();
      if (_active(generation) && token != null) {
        await ref.read(pushRegistrationProvider).register(token);
      }
    } catch (_) {}
  }

  void _refresh() {
    ref.invalidate(unreadNotificationsProvider);
    ref.invalidate(unreadMessagesProvider);
    ref.invalidate(inboxProvider);
    for (final kind in ['friends', 'incoming', 'outgoing']) {
      ref.invalidate(friendsProvider(kind));
    }
  }

  void _receive(AppNotification event) {
    if (!_foreground || event.recipientId != _user || !_seen.add(event.id)) {
      return;
    }
    if (_seen.length > 500) _seen.remove(_seen.first);
    _refresh();
    ref.read(notificationEventProvider.notifier).receive(event);
    final messenger = appMessengerKey.currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Text('${event.title}\n${event.body}'),
        action: SnackBarAction(
          label: 'Xem',
          onPressed: () => openNotification(ref, event),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _stopStream();
      return;
    }
    if (_user != null) {
      _refresh();
      _connect();
      if (_pushReady) unawaited(_registerToken(_generation));
    }
  }

  @override
  void dispose() {
    _generation++;
    _unreadPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    for (final subscription in _pushSubscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, auth) => _session(auth));
    return widget.child;
  }
}
