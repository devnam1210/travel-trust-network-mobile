import 'package:flutter/material.dart';

import '../place_model.dart';

class PlaceInfoSection extends StatelessWidget {
  const PlaceInfoSection({super.key, required this.place});

  final PlaceDetailModel place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge & Rating
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                place.category,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const Spacer(),
            const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
            const SizedBox(width: 4),
            Text(
              place.averageRating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              '(${place.verifiedReviewCount} đánh giá)',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Name
        Text(
          place.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Address
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_rounded, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                place.address,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Opening Hours
        if (place.openingHours?.trim().isNotEmpty == true) ...[
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 20,
                color: colors.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Giờ mở cửa: ${place.openingHours}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        const Divider(height: 24),

        // GPS Rule Card (Quy chuẩn vị trí)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withAlpha(120),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.gps_fixed_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Quy chuẩn xác thực GPS (Server-side)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Tọa độ chuẩn: ${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                '• Bán kính check-in hợp lệ: ≤ ${place.allowedRadiusM.toStringAsFixed(0)} mét (Công thức Haversine)',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Description
        if (place.description?.trim().isNotEmpty == true) ...[
          Text(
            'Giới thiệu',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            place.description!,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
