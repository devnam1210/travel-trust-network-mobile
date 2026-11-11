import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/api_service.dart';
import 'locket_service.dart';
import 'locket_widget_service.dart';
import '../auth/token_storage.dart';

const _taskName = 'locketWidgetPoll';

/// Chạy ở isolate nền: không có UI, tự đọc JWT rồi tải feed → cập nhật widget.
@pragma('vm:entry-point')
void locketCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final token = await const SecureTokenStorage().read();
      if (token == null) return true; // chưa đăng nhập: bỏ qua
      final api = ApiService()..accessToken = token;
      try {
        final feed = await LocketService(api: api).getFeed();
        if (await const SecureTokenStorage().read() == token) {
          await LocketWidgetService.updateFromFeed(feed);
        }
      } finally {
        api.close();
      }
      return true;
    } catch (_) {
      return false; // lỗi mạng: WorkManager tự thử lại
    }
  });
}

/// Đăng ký kiểm tra feed định kỳ khi app không mở (Android, tối thiểu 15 phút).
Future<void> startLocketBackgroundSync() async {
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(locketCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'locket_widget_poll',
    _taskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
