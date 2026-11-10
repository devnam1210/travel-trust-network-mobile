import 'package:flutter/material.dart';

import '../../visits/visit_model.dart';

class VerifiedVisitSection extends StatelessWidget {
  const VerifiedVisitSection({
    super.key,
    required this.verifiedVisits,
    required this.selectedVisitId,
    required this.onVisitChanged,
    required this.onCheckIn,
  });

  final List<VisitModel> verifiedVisits;
  final String? selectedVisitId;
  final ValueChanged<String?> onVisitChanged;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
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
              style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.gps_fixed_rounded, size: 18),
              label: const Text('Check-in ngay'),
              onPressed: onCheckIn,
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey(selectedVisitId),
      initialValue: selectedVisitId,
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.surfaceContainerHighest.withAlpha(100),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      items: verifiedVisits
          .map((v) {
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
          })
          .toList(growable: false),
      onChanged: onVisitChanged,
    );
  }
}
