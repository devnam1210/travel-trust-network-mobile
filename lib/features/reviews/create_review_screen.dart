import 'package:flutter/material.dart';

import '../../shared/widgets/motion_feedback.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../shared/widgets/error_notice.dart';
import '../auth/auth_controller.dart';
import '../places/place_providers.dart';
import '../visits/visit_screen.dart';
import '../visits/visit_service.dart';
import 'review_service.dart';
import 'widgets/review_rating_picker.dart';
import 'widgets/verified_visit_section.dart';

class CreateReviewScreen extends ConsumerStatefulWidget {
  const CreateReviewScreen({
    super.key,
    required this.placeId,
    required this.placeName,
    this.initialVisitId,
  });

  final String placeId;
  final String placeName;
  final String? initialVisitId;

  @override
  ConsumerState<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends ConsumerState<CreateReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _imageUrlController = TextEditingController();

  int _rating = 5;
  String? _selectedVisitId;
  bool _is360Media = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedVisitId = widget.initialVisitId;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _onVisitChanged(String? visitId) {
    setState(() => _selectedVisitId = visitId);
  }

  void _onRatingChanged(int rating) {
    setState(() => _rating = rating);
  }

  void _openVisit() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitScreen(placeId: widget.placeId),
      ),
    );
  }

  Future<void> _submitReview() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    final history = ref.read(visitHistoryProvider);
    final hasValidVisit =
        !history.isLoading &&
        !history.hasError &&
        (history.asData?.value.any(
              (visit) =>
                  visit.id == _selectedVisitId &&
                  visit.placeId == widget.placeId &&
                  visit.status == 'VERIFIED',
            ) ??
            false);
    if (!hasValidVisit) {
      setState(() {
        _error =
            'Vui lòng chọn chuyến đi đã xác thực để liên kết với đánh giá.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final reviewService = ref.read(reviewServiceProvider);
      await reviewService.createReview(
        visitId: _selectedVisitId!,
        placeId: widget.placeId,
        rating: _rating,
        comment: _commentController.text.trim(),
        postcardImageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        is360Media: _is360Media,
      );

      if (!mounted) return;

      // Cập nhật chi tiết địa điểm, lịch sử chuyến đi và hồ sơ từ máy chủ.
      ref.invalidate(placeDetailProvider(widget.placeId));
      ref.invalidate(visitHistoryProvider);
      await ref.read(authControllerProvider.notifier).refreshProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.stars_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đăng đánh giá thành công!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'DUPLICATE_REVIEW') {
          _error = 'Bạn đã từng gửi đánh giá cho địa điểm này rồi (Mỗi người dùng chỉ được đánh giá 1 lần).';
        } else if (e.code == 'UNVERIFIED_VISIT') {
          _error = 'Chuyến đi này chưa hoàn tất Check-out (chưa đạt trạng thái VERIFIED).';
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể gửi đánh giá: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final historyAsync = ref.watch(visitHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Viết đánh giá xác minh'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Place Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withAlpha(80),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.primary.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.place_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.placeName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 14,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Đánh giá kèm bằng chứng vị trí GPS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Select Verified Visit Section
                Text(
                  '1. Chuyến đi đã xác thực (Bắt buộc)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                historyAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => ErrorNotice(
                    message: 'Không thể tải lịch sử chuyến đi để kiểm tra.',
                  ),
                  data: (visits) {
                    final verifiedVisits = visits
                        .where(
                          (v) =>
                              v.placeId == widget.placeId &&
                              v.status == 'VERIFIED',
                        )
                        .toList(growable: false);

                    // Giữ lựa chọn hợp lệ; nếu không, chọn chuyến đầu tiên hoặc reset.
                    if (!verifiedVisits.any(
                      (visit) => visit.id == _selectedVisitId,
                    )) {
                      _selectedVisitId = verifiedVisits.isEmpty
                          ? null
                          : verifiedVisits.first.id;
                    }

                    return VerifiedVisitSection(
                      verifiedVisits: verifiedVisits,
                      selectedVisitId: _selectedVisitId,
                      onVisitChanged: _onVisitChanged,
                      onCheckIn: _openVisit,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 3. Rating Section
                Text(
                  '2. Mức độ hài lòng của bạn',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ReviewRatingPicker(
                  rating: _rating,
                  onRatingChanged: _onRatingChanged,
                ),
                const SizedBox(height: 24),

                // 4. Comment Textarea
                Text(
                  '3. Nhận xét chi tiết',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Chia sẻ trải nghiệm thực tế của bạn về địa điểm này (cảnh quan, dịch vụ, lời khuyên…)',
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withAlpha(100),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập nội dung đánh giá.';
                    }
                    if (value.trim().length < 5) {
                      return 'Nội dung nhận xét tối thiểu 5 ký tự.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 5. Postcard Image URL (Optional)
                Text(
                  '4. Ảnh kỷ niệm / Postcard (Tùy chọn)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: InputDecoration(
                    hintText: 'Nhập đường dẫn ảnh hoặc /uploads/...',
                    prefixIcon: const Icon(Icons.image_outlined),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withAlpha(100),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _is360Media,
                  onChanged: (val) =>
                      setState(() => _is360Media = val ?? false),
                  title: const Text('Đây là ảnh panorama / 360 độ'),
                  subtitle: const Text(
                    'Đánh dấu nội dung đa phương tiện 360 (nếu có)',
                    style: TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 20),

                // Error Display
                if (_error != null) ...[
                  ErrorNotice(message: _error!),
                  const SizedBox(height: 16),
                ],

                // 6. Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: BusyIcon(busy: _busy, icon: Icons.send_rounded),
                    label: Text(
                      _busy ? 'Đang gửi đánh giá…' : 'Đăng đánh giá',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _busy ? null : _submitReview,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
