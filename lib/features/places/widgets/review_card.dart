import 'package:flutter/material.dart';

import '../../../shared/motion/app_motion.dart';

import '../../reviews/review_model.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.colors,
    required this.theme,
    required this.onResolveImage,
  });

  final ReviewModel review;
  final ColorScheme colors;
  final ThemeData theme;
  final String? Function(String?) onResolveImage;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final postcardUrl = onResolveImage(review.postcardImageUrl);

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Text(
                    review.fullName.isNotEmpty
                        ? review.fullName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDate(review.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Star rating
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Comment
            Text(
              review.comment,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),

            // Postcard Image if available
            if (postcardUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  postcardUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: AppMotion.imageWidth(
                    context,
                    MediaQuery.sizeOf(context).width - 80,
                  ),
                  frameBuilder: AppMotion.imageFrame,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],

            const SizedBox(height: 8),
            // Verified Badge
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Đã xác thực chuyến đi qua GPS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
