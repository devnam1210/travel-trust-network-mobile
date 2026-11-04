import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../models/place_model.dart';
import '../../models/review_model.dart';
import '../../services/place_service.dart';
import '../auth/widgets/error_notice.dart';
import '../reviews/create_review_screen.dart';
import '../visits/visit_screen.dart';

final placeDetailProvider =
    FutureProvider.autoDispose.family<PlaceDetailModel, String>(
  (ref, placeId) async {
    final service = ref.watch(placeServiceProvider);
    return service.getPlaceDetail(placeId);
  },
);

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  String? _resolveImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    return Uri.parse(AppConfig.apiBaseUrl).resolve(rawUrl.trim()).toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final placeDetailAsync = ref.watch(placeDetailProvider(placeId));

    return Scaffold(
      body: placeDetailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Scaffold(
          appBar: AppBar(title: const Text('Chi tiết địa điểm')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ErrorNotice(message: 'Lỗi tải chi tiết địa điểm: $error'),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                    onPressed: () => ref.refresh(placeDetailProvider(placeId)),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (place) {
          final fullImageUrl = _resolveImageUrl(place.imageUrl);

          return CustomScrollView(
            slivers: [
              // 1. Sliver App Bar with Image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: fullImageUrl != null
                      ? Image.network(
                          fullImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _buildPlaceholder(colors),
                        )
                      : _buildPlaceholder(colors),
                ),
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: colors.surface.withAlpha(200),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded,
                          color: colors.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),

              // 2. Content Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge & Rating
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
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
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 22),
                          const SizedBox(width: 4),
                          Text(
                            place.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${place.verifiedReviewCount} đánh giá)',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
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
                          Icon(Icons.location_on_rounded,
                              size: 20, color: colors.primary),
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
                            Icon(Icons.access_time_rounded,
                                size: 20, color: colors.secondary),
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
                          border: Border.all(
                            color: colors.outlineVariant.withAlpha(80),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.gps_fixed_rounded,
                                    size: 18, color: colors.primary),
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
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Verified Reviews Section
                      Row(
                        children: [
                          Text(
                            'Đánh giá đã xác minh (${place.reviews.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.verified_user_rounded,
                              size: 18, color: colors.primary),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (place.reviews.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.rate_review_outlined,
                                  size: 40, color: colors.outline),
                              const SizedBox(height: 8),
                              const Text(
                                'Chưa có đánh giá nào.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hãy check-in thực tế tại đây để trở thành người đánh giá đầu tiên (+5 điểm uy tín)!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.rate_review_rounded,
                                    size: 18),
                                label: const Text('Viết đánh giá ngay'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => CreateReviewScreen(
                                        placeId: place.id,
                                        placeName: place.name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: place.reviews.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final review = place.reviews[index];
                            return _ReviewItemCard(
                              review: review,
                              colors: colors,
                              theme: theme,
                              onResolveImage: _resolveImageUrl,
                            );
                          },
                        ),

                      const SizedBox(height: 80), // Padding cho Bottom Bar
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // 3. Fixed Bottom Action Bar with 2 Buttons: Viết đánh giá & Check-in
      bottomNavigationBar: placeDetailAsync.maybeWhen(
        data: (place) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text(
                      'Viết đánh giá',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CreateReviewScreen(
                            placeId: place.id,
                            placeName: place.name,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.gps_fixed_rounded),
                    label: const Text(
                      'Check-in tại đây',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => VisitScreen(placeId: place.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 64,
          color: colors.outlineVariant,
        ),
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
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
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],

            const SizedBox(height: 8),
            // Verified Badge
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 14, color: Colors.green.shade600),
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
