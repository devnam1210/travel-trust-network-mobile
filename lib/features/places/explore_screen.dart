import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/error_notice.dart';
import '../../shared/widgets/motion_feedback.dart';
import 'place_detail_screen.dart';
import 'place_providers.dart';
import 'widgets/place_card.dart';

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

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  Future<void> _refreshPlaces() async {
    ref.invalidate(
      placesListProvider((keyword: _keyword, category: _selectedCategory)),
    );
  }

  void _openPlaceDetail(String placeId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaceDetailScreen(placeId: placeId),
      ),
    );
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
                        onPressed: _clearSearch,
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
              children: _categories
                  .map((cat) {
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
                  })
                  .toList(growable: false),
            ),
          ),

          // 3. Places List with States (Loading, Error, Empty, Success)
          LoadingLine(visible: placesAsync.isLoading),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPlaces,
              child: placesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
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
                          onPressed: _refreshPlaces,
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
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    key: PageStorageKey((
                      'places',
                      _keyword,
                      _selectedCategory,
                    )),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: places.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final place = places[index];
                      return PlaceCard(
                        key: ValueKey(place.id),
                        place: place,
                        onTap: () => _openPlaceDetail(place.id),
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
