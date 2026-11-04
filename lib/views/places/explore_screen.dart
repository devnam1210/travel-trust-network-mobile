import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../models/place_model.dart';
import '../../services/place_service.dart';
import '../auth/widgets/error_notice.dart';
import 'place_detail_screen.dart';

// Provider tìm kiếm địa điểm kết hợp keyword và category
final placesListProvider = FutureProvider.autoDispose
    .family<List<PlaceSummaryModel>, ({String keyword, String category})>(
  (ref, query) async {
    final service = ref.watch(placeServiceProvider);
    return service.searchPlaces(
      keyword: query.keyword,
      category: query.category == 'ALL' ? null : query.category,
    );
  },
);

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _requestVersion = 0;

  String _keyword = '';
  String _selectedCategory = 'ALL';

  final List<({String label, String value})> _categories = const [
    (label: 'Tất cả', value: 'ALL'),
    (label: 'Khuôn viên (Campus)', value: 'CAMPUS'),
    (label: 'Di tích (Heritage)', value: 'HERITAGE'),
    (label: 'Thiên nhiên (Nature)', value: 'NATURE'),
  ];

  @override
  void dispose() {
    ++_requestVersion;
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Kỹ thuật Debounce 500ms chống spam request và race condition
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final version = ++_requestVersion;
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || version != _requestVersion) return;
      setState(() => _keyword = value.trim());
    });
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final placesAsync = ref.watch(
      placesListProvider((keyword: _keyword, category: _selectedCategory)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Khám phá điểm đến',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm địa điểm, địa chỉ…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.surfaceContainerHighest.withAlpha(120),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2. Filter Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.label),
                    selected: isSelected,
                    onSelected: (_) => _onCategorySelected(cat.value),
                    selectedColor: colors.primaryContainer,
                    checkmarkColor: colors.onPrimaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),

          // 3. Places List with States (Loading, Error, Empty, Success)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(placesListProvider(
                    (keyword: _keyword, category: _selectedCategory)));
              },
              child: placesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        ErrorNotice(
                          message: 'Không thể tải danh sách địa điểm: $error',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Thử lại'),
                          onPressed: () {
                            ref.invalidate(placesListProvider((
                              keyword: _keyword,
                              category: _selectedCategory,
                            )));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                data: (places) {
                  if (places.isEmpty) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 60),
                              Icon(
                                Icons.travel_explore_rounded,
                                size: 64,
                                color: colors.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Không tìm thấy địa điểm nào',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hãy thử tìm kiếm với từ khóa khác hoặc bỏ bộ lọc danh mục.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: places.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final place = places[index];
                      return _PlaceCard(
                        place: place,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  PlaceDetailScreen(placeId: place.id),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onTap});

  final PlaceSummaryModel place;
  final VoidCallback onTap;

  String? _resolveImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    return Uri.parse(AppConfig.apiBaseUrl).resolve(rawUrl.trim()).toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fullImageUrl = _resolveImageUrl(place.imageUrl);

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
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
                            horizontal: 8, vertical: 4),
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
                      Icon(Icons.location_on_outlined,
                          size: 16, color: colors.onSurfaceVariant),
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
                      const Icon(Icons.star_rounded,
                          size: 18, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        place.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.verified_outlined,
                          size: 16, color: colors.primary),
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
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: colors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
