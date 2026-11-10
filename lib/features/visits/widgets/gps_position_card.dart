import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../places/place_model.dart';
import '../../../shared/widgets/motion_feedback.dart';

class GpsPositionCard extends StatelessWidget {
  const GpsPositionCard({
    super.key,
    required this.placeAsync,
    required this.position,
    required this.isBusy,
    required this.showMeasureButton,
    required this.onMeasurePosition,
  });

  final AsyncValue<PlaceDetailModel> placeAsync;
  final Position? position;
  final bool isBusy;
  final bool showMeasureButton;
  final VoidCallback onMeasurePosition;

  @override
  Widget build(BuildContext context) {
    final position = this.position;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kiểm tra vị trí check-in'),
            const SizedBox(height: 8),
            placeAsync.when(
              loading: () => const Text('Đang tải vị trí địa điểm…'),
              error: (_, _) => const Text('Chưa tải được vị trí địa điểm.'),
              data: (place) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name),
                  SelectableText(
                    'Tọa độ địa điểm: ${place.latitude.toStringAsFixed(6)}, ${place.longitude.toStringAsFixed(6)}',
                  ),
                  Text(
                    'Bán kính check-in: ${place.allowedRadiusM.toStringAsFixed(0)} m',
                  ),
                  if (position != null)
                    Text(
                      'Khoảng cách ước tính: ${Geolocator.distanceBetween(position.latitude, position.longitude, place.latitude, place.longitude).toStringAsFixed(1)} m',
                    ),
                ],
              ),
            ),
            if (position != null) ...[
              const Divider(),
              SelectableText(
                'GPS điện thoại: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
              ),
              Text(
                position.hasAccuracy
                    ? 'Sai số ước tính: ±${position.accuracy.toStringAsFixed(1)} m'
                    : 'Điện thoại chưa cung cấp sai số vị trí.',
              ),
              Text('Thời điểm đo: ${position.timestamp.toLocal()}'),
              if (!position.hasAccuracy || position.accuracy > 50)
                const Text(
                  'Vị trí chưa ổn định. Hãy bật Vị trí chính xác và thử đo lại ở nơi thoáng.',
                ),
            ],
            if (showMeasureButton)
              OutlinedButton.icon(
                onPressed: isBusy ? null : onMeasurePosition,
                icon: BusyIcon(busy: isBusy, icon: Icons.my_location),
                label: const Text('Kiểm tra GPS / Đo lại'),
              ),
          ],
        ),
      ),
    );
  }
}
