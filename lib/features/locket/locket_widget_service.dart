import 'dart:io';

import 'package:dio/dio.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_config.dart';
import 'locket_model.dart';

/// Đẩy ảnh Locket mới nhất ra widget màn hình chính (Android).
class LocketWidgetService {
  static Future<void> updateFromFeed(List<LocketSignal> feed) async {
    if (!Platform.isAndroid) return;
    try {
      if (feed.isEmpty) {
        await HomeWidget.saveWidgetData<String>('locket_image_path', null);
        await HomeWidget.saveWidgetData('locket_sender', '');
        await HomeWidget.saveWidgetData('locket_caption', '');
        await HomeWidget.updateWidget(androidName: 'LocketWidgetProvider');
        return;
      }
      final latest = feed.first;
      if (latest.mediaId != null) {
        // Private photos stay behind authentication and are never copied into a widget disk cache.
        await HomeWidget.saveWidgetData<String>('locket_image_path', null);
        await HomeWidget.saveWidgetData('locket_sender', 'Locket');
        await HomeWidget.saveWidgetData(
          'locket_caption',
          'Mở ứng dụng để xem ảnh mới',
        );
        await HomeWidget.updateWidget(androidName: 'LocketWidgetProvider');
        return;
      }
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
