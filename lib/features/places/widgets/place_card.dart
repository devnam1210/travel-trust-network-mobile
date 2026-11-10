import 'package:flutter/material.dart';

import '../../../core/app_config.dart';
import '../../../shared/motion/app_motion.dart';
import '../place_model.dart';

class PlaceCard extends StatefulWidget {
  const PlaceCard({super.key, required this.place, required this.onTap});

  final PlaceSummaryModel place;
  final VoidCallback onTap;

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  bool _pressed = false;
  PlaceSummaryModel get place => widget.place;

  String? _resolveImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    return Uri.parse(AppConfig.apiBaseUrl).resolve(rawUrl.trim()).toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fullImageUrl = _resolveImageUrl(place.imageUrl);

    return AnimatedScale(
      scale: _pressed && !AppMotion.reduced(context) ? 0.985 : 1,
      duration: AppMotion.duration(context, AppMotion.press),
      curve: AppMotion.curve,
      child: Card(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image header
              SizedBox(
                height: 160,
                width: double.infinity,
                child: fullImageUrl != null
                    ? Image.network(
                        fullImageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: AppMotion.imageWidth(
                          context,
                          MediaQuery.sizeOf(context).width - 32,
                        ),
                        frameBuilder: AppMotion.imageFrame,
                        errorBuilder: (_, _, _) => _buildPlaceholder(colors),
                      )
                    : _buildPlaceholder(colors),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            place.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            place.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.address,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          place.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.verified_outlined,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${place.verifiedReviewCount} đánh giá',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Xem chi tiết',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 48,
          color: colors.outlineVariant,
        ),
      ),
    );
  }
}
