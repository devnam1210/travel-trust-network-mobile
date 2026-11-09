import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';
import '../../services/api_service.dart';
import '../../services/review_service.dart';
import '../../services/visit_service.dart';
import '../auth/widgets/error_notice.dart';
import '../places/place_detail_screen.dart';
import '../studio/studio_screen.dart';
import '../visits/visit_screen.dart';

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

  final List<String> _ratingLabels = const [
    'Rất tệ',
    'Tạm được',
    'Bình thường',
    'Hài lòng',
    'Tuyệt vời!',
  ];

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

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVisitId == null) {
      setState(() {
        _error = 'Vui lòng chọn chuyến đi đã xác thực để liên kết với đánh giá.';
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

      // Cập nhật lại các Provider liên quan: Chi tiết địa điểm, Hồ sơ (+5 điểm) và Lịch sử chuyến đi
      ref.invalidate(placeDetailProvider(widget.placeId));
      ref.invalidate(visitHistoryProvider);
      await ref.read(authControllerProvider.notifier).refreshProfile();

      if (!mounted) return;

      // Hiển thị thông báo chúc mừng nhận điểm uy tín
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.stars_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đăng đánh giá thành công! Bạn nhận được +5 điểm uy tín.',
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
                                Icon(Icons.verified_user_rounded,
                                    size: 14, color: colors.primary),
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
                        .where((v) =>
                            v.placeId == widget.placeId &&
                            v.status == 'VERIFIED')
                        .toList(growable: false);

                    if (verifiedVisits.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.amber.shade900),
                                const SizedBox(width: 8),
                                Text(
                                  'Chưa có chuyến đi hoàn tất',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Quy chuẩn chống đánh giá ảo yêu cầu bạn phải Check-in và Check-out thực tế tại địa điểm này trước khi đăng nhận xét.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                              label: const Text('Check-in ngay'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        VisitScreen(placeId: widget.placeId),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }

                    // Tự động chọn chuyến đi đầu tiên nếu chưa chọn
                    _selectedVisitId ??= verifiedVisits.first.id;

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedVisitId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.surfaceContainerHighest.withAlpha(100),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: verifiedVisits.map((v) {
                        final checkOut = v.checkOutTime?.toLocal();
                        final dateStr = checkOut != null
                            ? '${checkOut.day}/${checkOut.month}/${checkOut.year} ${checkOut.hour}:${checkOut.minute.toString().padLeft(2, '0')}'
                            : 'Đã xác thực';
                        return DropdownMenuItem<String>(
                          value: v.id,
                          child: Text(
                            'Chuyến đi ngày $dateStr',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(growable: false),
                      onChanged: (val) {
                        setState(() => _selectedVisitId = val);
                      },
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
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          return IconButton(
                            iconSize: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            icon: Icon(
                              starIndex <= _rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: Colors.amber,
                            ),
                            onPressed: () => setState(() => _rating = starIndex),
                          );
                        }),
                      ),
                      Text(
                        _ratingLabels[_rating - 1],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
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
                    hintText:
                        'Chia sẻ trải nghiệm thực tế của bạn về địa điểm này (cảnh quan, dịch vụ, lời khuyên…)',
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
                OutlinedButton.icon(
                  icon: const Icon(Icons.brush_outlined),
                  label: const Text('Tạo postcard trong Studio'),
                  onPressed: () async {
                    final url = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => StudioScreen(
                          placeId: widget.placeId,
                          placeName: widget.placeName,
                          visitId: _selectedVisitId,
                        ),
                      ),
                    );
                    if (url != null) {
                      setState(() {
                        _imageUrlController.text = url;
                        _is360Media = false;
                      });
                    }
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _is360Media,
                  onChanged: (val) => setState(() => _is360Media = val ?? false),
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
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _busy ? 'Đang gửi đánh giá…' : 'Đăng đánh giá (+5 điểm)',
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
