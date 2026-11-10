import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_service.dart';

class LocketAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    final signal = {
      'id': 'signal-1',
      'senderName': 'Test User',
      'placeName': 'Campus',
      'mediaId': 'media-1',
      'imageUrl': '/api/v1/media/private/media-1',
      'recipientIds': ['friend-1'],
      'reactions': [
        {'userId': 'friend-1', 'userName': 'Friend', 'emoji': '❤️'},
      ],
      'caption': 'Hello',
      'is360Image': true,
      'sentAt': '2026-11-10T10:00:00Z',
    };
    final Object data;
    switch (options.path) {
      case '/media/private':
        data = {'mediaId': 'media-1'};
      case '/locket/send-signal':
        data = signal;
      case '/locket/feed':
        data = [signal];
      default:
        throw StateError('Unexpected Locket endpoint: ${options.path}');
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
  late LocketAdapter adapter;
  late ApiService api;
  late LocketService service;

  setUp(() {
    adapter = LocketAdapter();
    api = ApiService(dio: Dio()..httpClientAdapter = adapter)
      ..accessToken = 'test-token';
    service = LocketService(api: api);
  });
  tearDown(() => api.close());

  test(
    'upload, send and feed preserve multipart, endpoints, JSON and model',
    () async {
      final imagePath = File('assets/images/fpt_hoa_lac.jpg').absolute.path;
      final url = await service.uploadImage(imagePath);
      expect(url, 'media-1');
      final upload = adapter.requests.single;
      expect(upload.path, '/media/private');
      expect(upload.method, 'POST');
      expect(upload.contentType, startsWith('multipart/form-data; boundary='));
      final form = upload.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'fpt_hoa_lac.jpg');
      expect(form.files.single.value.length, File(imagePath).lengthSync());

      final sent = await service.sendSignal(
        mediaId: url,
        recipientIds: ['friend-1'],
        placeId: 'place-1',
        caption: 'Hello',
        is360Image: true,
      );
      final send = adapter.requests.last;
      expect(send.path, '/locket/send-signal');
      expect(send.method, 'POST');
      expect(send.data, {
        'mediaId': 'media-1',
        'recipientIds': ['friend-1'],
        'allFriends': false,
        'placeId': 'place-1',
        'caption': 'Hello',
        'is360Image': true,
      });
      expect(sent.id, 'signal-1');
      final feed = await service.getFeed();
      expect(adapter.requests.last.path, '/locket/feed');
      expect(adapter.requests.last.method, 'GET');
      expect(feed.single.id, sent.id);
      expect(feed.single.senderName, 'Test User');
      expect(feed.single.placeName, 'Campus');
      expect(feed.single.mediaId, url);
      expect(feed.single.imageUrl, '/api/v1/media/private/media-1');
      expect(feed.single.recipientIds, ['friend-1']);
      expect(feed.single.reactions.single.emoji, '❤️');
      expect(feed.single.caption, 'Hello');
      expect(feed.single.is360Image, isTrue);
      expect(feed.single.sentAt, DateTime.utc(2026, 11, 10, 10));
      for (final request in adapter.requests) {
        expect(request.headers['Authorization'], 'Bearer test-token');
      }
    },
  );

  test(
    'optional signal fields preserve omission and non-null values',
    () async {
      await service.sendSignal(
        mediaId: 'media-1',
        allFriends: true,
        caption: '',
      );
      expect(adapter.requests.last.data, {
        'mediaId': 'media-1',
        'recipientIds': [],
        'allFriends': true,
        'is360Image': false,
      });
      await service.sendSignal(
        mediaId: 'media-1',
        recipientIds: ['friend-1'],
        placeId: '',
        caption: ' ',
      );
      expect(adapter.requests.last.data, {
        'mediaId': 'media-1',
        'recipientIds': ['friend-1'],
        'allFriends': false,
        'placeId': '',
        'caption': ' ',
        'is360Image': false,
      });
    },
  );
}
