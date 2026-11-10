import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../shared/widgets/error_notice.dart';
import '../../shared/motion/app_motion.dart';
import '../reviews/create_review_screen.dart';
import '../visits/visit_screen.dart';
import 'place_model.dart';
import 'place_providers.dart';
import 'widgets/place_info_section.dart';
import 'widgets/review_card.dart';

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  void _openVisit(BuildContext context, PlaceDetailModel place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => VisitScreen(placeId: place.id)),
    );
  }

  void _openReview(BuildContext context, PlaceDetailModel place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CreateReviewScreen(placeId: place.id, placeName: place.name),
      ),
    );
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
            key: PageStorageKey('place-detail-$placeId'),
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
                          cacheWidth: AppMotion.imageWidth(
                            context,
                            MediaQuery.sizeOf(context).width,
                          ),
                          frameBuilder: AppMotion.imageFrame,
                          errorBuilder: (_, _, _) => _buildPlaceholder(colors),
                        )
                      : _buildPlaceholder(colors),
                ),
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: colors.surface.withAlpha(200),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: colors.onSurface,
                      ),
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
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.6, end: 1),
                        duration: AppMotion.duration(context, AppMotion.fade),
                        curve: AppMotion.curve,
                        child: PlaceInfoSection(place: place),
                        builder: (_, opacity, child) =>
                            Opacity(opacity: opacity, child: child),
                      ),

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
                          Icon(
                            Icons.verified_user_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
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
                              Icon(
                                Icons.rate_review_outlined,
                                size: 40,
                                color: colors.outline,
                              ),
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
                                icon: const Icon(
                                  Icons.rate_review_rounded,
                                  size: 18,
                                ),
                                label: const Text('Viết đánh giá ngay'),
                                onPressed: () => _openReview(context, place),
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
                            return ReviewCard(
                              key: ValueKey(review.id),
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
                    onPressed: () => _openReview(context, place),
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
                    onPressed: () => _openVisit(context, place),
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

  String? _resolveImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    return Uri.parse(AppConfig.apiBaseUrl).resolve(rawUrl.trim()).toString();
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
