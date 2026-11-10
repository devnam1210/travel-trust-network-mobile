import 'package:flutter/material.dart';

import '../../../shared/motion/app_motion.dart';
import '../../../shared/widgets/motion_feedback.dart';

class ReviewRatingPicker extends StatelessWidget {
  const ReviewRatingPicker({
    super.key,
    required this.rating,
    required this.onRatingChanged,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;

  static const List<String> _ratingLabels = [
    'Rất tệ',
    'Tạm được',
    'Bình thường',
    'Hài lòng',
    'Tuyệt vời!',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return IconButton(
                iconSize: 42,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                icon: AnimatedScale(
                  scale: starIndex == rating && !AppMotion.reduced(context)
                      ? 1.06
                      : 1,
                  duration: AppMotion.duration(context, AppMotion.feedback),
                  curve: AppMotion.curve,
                  child: Icon(
                    starIndex <= rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                  ),
                ),
                onPressed: () => onRatingChanged(starIndex),
              );
            }),
          ),
          MotionSwitcher(
            child: Text(
              key: ValueKey(rating),
              _ratingLabels[rating - 1],
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
