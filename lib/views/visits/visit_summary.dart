import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/visit_model.dart';

class VisitSummary extends StatelessWidget {
  const VisitSummary({super.key, required this.visit});

  final VisitModel visit;

  String _time(DateTime? value) {
    if (value == null) return 'Chưa Check-out';
    final date = value.toLocal();
    String pad(int number) => number.toString().padLeft(2, '0');
    return '${pad(date.day)}/${pad(date.month)}/${date.year} '
        '${pad(date.hour)}:${pad(date.minute)}:${pad(date.second)}';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (visit.placeImageUrl?.trim().isNotEmpty == true) ...[
        Image.network(
          Uri.parse(AppConfig.apiBaseUrl)
              .resolve(visit.placeImageUrl!)
              .toString(),
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image_outlined),
        ),
        const SizedBox(height: 12),
      ],
      Text(visit.placeName, style: Theme.of(context).textTheme.titleMedium),
      Text('Trạng thái: ${visit.status}'),
      Text('Check-in: ${_time(visit.checkInTime)}'),
      Text('Check-out: ${_time(visit.checkOutTime)}'),
      if (visit.distanceMeters != null)
        Text(
          'Khoảng cách Check-in: ${visit.distanceMeters!.toStringAsFixed(1)} m',
        ),
      if (visit.rejectionReason != null)
        Text('Lý do: ${visit.rejectionReason}'),
    ],
  );
}
