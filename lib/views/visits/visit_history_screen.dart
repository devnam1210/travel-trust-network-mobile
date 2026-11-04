import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_service.dart';
import '../../services/visit_service.dart';
import '../reviews/create_review_screen.dart';
import 'visit_screen.dart';
import 'visit_summary.dart';

class VisitHistoryScreen extends ConsumerWidget {
  const VisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(visitHistoryProvider);
    Future<void> refresh() async {
      try {
        ref.invalidate(visitHistoryProvider);
        await ref.read(visitHistoryProvider.future);
      } catch (_) {
        // The provider displays the error and retains the retry action.
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử chuyến đi')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: history.when(
          skipLoadingOnRefresh: false,
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 80),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                error is ApiException
                    ? error.message
                    : 'Không thể tải lịch sử chuyến đi.',
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: refresh, child: const Text('Thử lại')),
            ],
          ),
          data: (visits) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (visits.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Bạn chưa có chuyến đi nào. Kéo xuống để làm mới.',
                  ),
                ),
              for (final visit in visits)
                Card(
                  child: InkWell(
                    onTap: !visit.isOpen
                        ? null
                        : () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => VisitScreen(
                                  placeId: visit.placeId,
                                  visitId: visit.id,
                                  initialVisit: visit,
                                ),
                              ),
                            );
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VisitSummary(visit: visit),
                          if (visit.isOpen)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Nhấn để tiếp tục Check-out →',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (visit.status == 'VERIFIED') ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonalIcon(
                                icon: const Icon(Icons.rate_review_outlined,
                                    size: 16),
                                label: const Text('Viết đánh giá (+5 điểm)'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => CreateReviewScreen(
                                        placeId: visit.placeId,
                                        placeName: visit.placeName,
                                        initialVisitId: visit.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
