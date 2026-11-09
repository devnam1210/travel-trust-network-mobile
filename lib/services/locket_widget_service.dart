import 'dart:io';

import 'package:dio/dio.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../models/locket_model.dart';

/// Đẩy ảnh Locket mới nhất ra widget màn hình chính (Android).
class LocketWidgetService {
  static Future<void> updateFromFeed(List<LocketSignal> feed) async {
    if (!Platform.isAndroid || feed.isEmpty) return;
    try {
      final latest = feed.first;
      final url = Uri.parse(AppConfig.apiBaseUrl).resolve(latest.imageUrl);
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/locket_widget.jpg';
      await Dio().download(url.toString(), path);
      await HomeWidget.saveWidgetData('locket_image_path', path);
      await HomeWidget.saveWidgetData('locket_sender', latest.senderName);
      await HomeWidget.saveWidgetData('locket_caption', latest.caption ?? '');
      await HomeWidget.updateWidget(androidName: 'LocketWidgetProvider');
    } catch (_) {
      // Widget chỉ là phần phụ: lỗi mạng/file thì bỏ qua, không ảnh hưởng feed.
    }
  }
}
