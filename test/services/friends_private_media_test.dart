import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/friends/friend_service.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_service.dart';

class FriendsMediaAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Completer<void>? pending;
  static final bytes = Uint8List.fromList([137, 80, 78, 71]);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await pending?.future;
    if (status != 200) {
      return ResponseBody.fromString(
        jsonEncode({
          'success': false,
          'code': 'UNAUTHORIZED',
          'message': 'Expired',
        }),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path.startsWith('/media/private/')) {
      return ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          Headers.contentTypeHeader: ['image/png'],
        },
      );
    }
    final Object data;
    if (options.path == '/friends/username') {
      data = {'username': 'my_name'};
    } else if (options.path.startsWith('/friends/users/')) {
      data = {
        'id': 'friend',
        'fullName': 'Hầu Văn Hòa',
        'relationship': 'FRIEND',
      };
    } else if (options.path.startsWith('/locket/users/')) {
      data = [
        {
          'id': 'photo',
          'senderId': 'friend',
          'senderName': 'Hầu Văn Hòa',
          'mediaId': 'private-image',
          'sentAt': '2026-11-10T09:30:00',
        },
      ];
    } else if (options.path.startsWith('/locket/') && options.method != 'GET') {
      data = {
        'id': 'signal',
        'senderName': 'Sender',
        'mediaId': 'media',
        'reactions': [],
      };
    } else if (options.method == 'GET' && options.path.startsWith('/friends')) {
      data = [
        {
          'id': 'friend',
          'username': 'my_friend',
          'fullName': 'Friend',
          'relationshipId': 'relation',
          'relationship': 'INCOMING',
        },
      ];
    } else {
      data = options.method == 'GET' ? [] : {'removed': true};
    }
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FriendsMediaAdapter adapter;
  late ApiService api;
  setUp(() {
    adapter = FriendsMediaAdapter();
    api = ApiService(dio: Dio()..httpClientAdapter = adapter)
      ..accessToken = 'jwt';
  });
  tearDown(() => api.close());

  test(
    'friends lifecycle sends exact methods, IDs, filters and username payload',
    () async {
      final service = FriendService(api: api);
      final found = await service.search(' my_friend ');
      expect(found.single.relationship, 'INCOMING');
      expect(found.single.relationshipId, 'relation');
      expect(
        adapter.requests.last.uri.queryParameters['username'],
        'my_friend',
      );
      await service.list('incoming');
      expect(adapter.requests.last.uri.queryParameters['kind'], 'incoming');
      await service.request('friend');
      expect(adapter.requests.last.path, '/friends/requests/friend');
      expect(adapter.requests.last.method, 'POST');
      await service.accept('relation');
      expect(adapter.requests.last.path, '/friends/requests/relation/accept');
      expect(adapter.requests.last.method, 'PUT');
      for (final action in ['reject', 'cancel', 'unfriend']) {
        await service.remove('relation', action);
        expect(adapter.requests.last.path, '/friends/relation/$action');
        expect(adapter.requests.last.method, 'DELETE');
      }
      expect(await service.updateUsername(' my_name '), 'my_name');
      expect(adapter.requests.last.data, {'username': 'my_name'});
      for (final request in adapter.requests) {
        expect(request.headers['Authorization'], 'Bearer jwt');
      }
    },
  );

  test(
    'friend search encodes a Vietnamese full name and preserves spaces',
    () async {
      await FriendService(api: api).search('  Hầu Văn Hòa  ');
      final request = adapter.requests.single;
      expect(request.uri.queryParameters['username'], 'Hầu Văn Hòa');
      expect(request.headers['Authorization'], 'Bearer jwt');
    },
  );

  test(
    'friend profile and photos preserve authentication, page and timestamp',
    () async {
      final person = await FriendService(api: api).profile('friend');
      expect(person.fullName, 'Hầu Văn Hòa');
      expect(adapter.requests.last.path, '/friends/users/friend/profile');
      final posts = await LocketService(api: api)
          .getUserPosts('friend', page: 2);
      expect(
        adapter.requests.last.uri.path,
        endsWith('/locket/users/friend/posts'),
      );
      expect(adapter.requests.last.uri.queryParameters, {
        'page': '2',
        'size': '20',
      });
      expect(posts.single.senderId, person.id);
      expect(posts.single.sentAt, DateTime(2026, 11, 10, 9, 30));
      for (final request in adapter.requests) {
        expect(request.headers['Authorization'], 'Bearer jwt');
      }
    },
  );

  test('private bytes use JWT, reject redirects and never use a supplied image URL', () async {
    expect(await api.getPrivateImage('media'), FriendsMediaAdapter.bytes);
    final request = adapter.requests.single;
    expect(request.path, '/media/private/media');
    expect(request.responseType, ResponseType.bytes);
    expect(request.followRedirects, isFalse);
    expect(request.uri.query, isEmpty);
    expect(request.headers['Authorization'], 'Bearer jwt');
    adapter.status = 302;
    await expectLater(
      api.getPrivateImage('media'),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.requests, hasLength(2));
  });

  for (final path in [
    '/friends',
    '/friends?kind=incoming',
    '/friends/search?username=test',
    '/locket/feed',
    '/messages/conversations',
    '/media/private',
  ]) {
    test('401 at $path expires the shared session exactly once', () async {
      var expirations = 0;
      api.onVisitUnauthorized = () async {
        expirations++;
      };
      adapter.status = 401;
      await expectLater(
        api.get(path),
        throwsA(
          isA<ApiException>().having((e) => e.isUnauthorized, '401', true),
        ),
      );
      expect(api.accessToken, isNull);
      await expectLater(api.get(path), throwsA(isA<ApiException>()));
      expect(expirations, 1);
    });
  }

  test('binary 401 decodes the API error and expires the session', () async {
    adapter.status = 401;
    var expired = false;
    api.onVisitUnauthorized = () async {
      expired = true;
    };
    await expectLater(
      api.getPrivateImage('media'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Expired')
            .having((e) => e.statusCode, 'status', 401),
      ),
    );
    expect(expired, isTrue);
  });

  test('late 401 from an old session does not clear a new token', () async {
    adapter.status = 401;
    adapter.pending = Completer();
    final pending = api.get('/friends');
    final assertion = expectLater(pending, throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);
    api.accessToken = 'new-session';
    adapter.pending!.complete();
    await assertion;
    expect(api.accessToken, 'new-session');
  });

  test(
    'existing places and public upload error handling stays unchanged',
    () async {
      adapter.status = 401;
      for (final path in ['/places', '/media/upload', '/users/me/profile']) {
        await expectLater(api.get(path), throwsA(isA<ApiException>()));
        expect(api.accessToken, 'jwt');
      }
    },
  );

  test('reactions and history use private Locket endpoints', () async {
    final service = LocketService(api: api);
    await service.react('signal', '❤️');
    expect(adapter.requests.last.method, 'PUT');
    expect(adapter.requests.last.data, {'emoji': '❤️'});
    await service.react('signal', null);
    expect(adapter.requests.last.path, '/locket/signal/reaction');
    expect(adapter.requests.last.method, 'DELETE');
    await service.getHistory(kind: 'received', page: 2);
    expect(adapter.requests.last.uri.queryParameters, {
      'kind': 'received',
      'page': '2',
      'size': '20',
    });
  });
}
