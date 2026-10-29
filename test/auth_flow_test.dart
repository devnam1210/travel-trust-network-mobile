import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/controllers/auth_controller.dart';
import 'package:travel_trust_network_mobile/main.dart';
import 'package:travel_trust_network_mobile/services/api_service.dart';
import 'package:travel_trust_network_mobile/views/auth/login_screen.dart';
import 'package:travel_trust_network_mobile/views/auth/register_screen.dart';
import 'package:travel_trust_network_mobile/views/profile_screen.dart';

import 'support/auth_fakes.dart';

void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;
  late ApiService api;

  setUp(() {
    backend = FakeBackend();
    storage = MemoryTokenStorage();
    api = ApiService(dio: Dio()..httpClientAdapter = backend);
  });

  tearDown(() => api.close());

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          tokenStorageProvider.overrideWithValue(storage),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
  }

  testWidgets('register submits credentials and logout returns to login', (
    tester,
  ) async {
    await openApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));
    expect(find.byType(RegisterScreen), findsOneWidget);

    await enter(tester, 'Họ và tên', 'Người du lịch');
    await enter(tester, 'Email (Gmail)', 'traveler@gmail.com');
    await enter(tester, 'Mật khẩu', 'my-app-password');
    await enter(tester, 'Xác nhận mật khẩu', 'my-app-password');
    await tapVisible(tester, find.text('Đăng ký'));

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Người du lịch'), findsOneWidget);
    expect(backend.requests.single.path, '/auth/register');
    expect(storage.token, 'backend-jwt');

    await tapVisible(tester, find.text('Đăng xuất'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(storage.token, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login handles a bad password and permits retry', (tester) async {
    backend.respond = (_) => apiResponse(
      null,
      status: 401,
      message: 'Email hoặc mật khẩu không đúng.',
    );
    await openApp(tester);
    await enter(tester, 'Email (Gmail)', 'traveler@gmail.com');
    await enter(tester, 'Mật khẩu', 'wrong-password');
    await tapVisible(tester, find.text('Đăng nhập'));
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);

    backend.respond = null;
    await enter(tester, 'Mật khẩu', 'my-app-password');
    await tapVisible(tester, find.text('Đăng nhập'));
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets(
    'invalid or mismatched registration form does not call the backend',
    (tester) async {
      await openApp(tester);
      await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));
      await tapVisible(tester, find.text('Đăng ký'));
      expect(find.text('Vui lòng nhập email.'), findsOneWidget);
      expect(backend.requests, isEmpty);

      await enter(tester, 'Họ và tên', 'Traveler');
      await enter(tester, 'Email (Gmail)', 'invalid-email');
      await enter(tester, 'Mật khẩu', 'short');
      await enter(tester, 'Xác nhận mật khẩu', 'different');
      await tapVisible(tester, find.text('Đăng ký'));
      expect(find.text('Email không hợp lệ.'), findsOneWidget);
      expect(find.text('Mật khẩu cần từ 8 đến 128 ký tự.'), findsOneWidget);
      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
      expect(backend.requests, isEmpty);
    },
  );

  testWidgets('duplicate registration shows the backend conflict', (
    tester,
  ) async {
    backend.respond = (_) =>
        apiResponse(null, status: 409, message: 'Email đã được đăng ký.');
    await openApp(tester);
    await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));
    await enter(tester, 'Họ và tên', 'Traveler');
    await enter(tester, 'Email (Gmail)', 'traveler@gmail.com');
    await enter(tester, 'Mật khẩu', 'my-app-password');
    await enter(tester, 'Xác nhận mật khẩu', 'my-app-password');
    await tapVisible(tester, find.text('Đăng ký'));
    expect(find.text('Email đã được đăng ký.'), findsOneWidget);
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('temporary session restore error offers retry', (tester) async {
    storage.token = 'saved-jwt';
    backend.respond = (_) =>
        apiResponse(null, status: 503, message: 'Máy chủ đang bận');
    await openApp(tester);
    expect(find.text('Chưa thể khôi phục phiên'), findsOneWidget);
    expect(storage.token, 'saved-jwt');

    backend.respond = null;
    await tapVisible(tester, find.text('Thử lại'));
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('small screens scroll through both forms', (tester) async {
    await openApp(tester);
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));
    expect(find.byType(RegisterScreen), findsOneWidget);
    await tapVisible(tester, find.text('Đã có tài khoản? Đăng nhập'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
