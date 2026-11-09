import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/models/visit_model.dart';
import 'package:travel_trust_network_mobile/services/visit_service.dart';
import 'package:travel_trust_network_mobile/views/studio/studio_screen.dart';

void main() {
  testWidgets('Studio shows GPS stamp and adds a sticker layer', (t) async {
    final visit = VisitModel(
      id: 'v1',
      placeId: 'p1',
      placeName: 'Hội An',
      status: 'VERIFIED',
      checkInTime: DateTime(2026, 1, 2),
      checkOutTime: DateTime(2026, 1, 2, 10),
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [visitHistoryProvider.overrideWith((ref) async => [visit])],
        child: const MaterialApp(
          home: StudioScreen(placeId: 'p1', placeName: 'Hội An'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('ĐÃ XÁC MINH GPS'), findsOneWidget);

    await t.scrollUntilVisible(find.text('⭐'), 200);
    await t.tap(find.text('⭐'));
    await t.pump();
    expect(find.text('⭐'), findsNWidgets(2)); // nút + lớp trên canvas
  });
}
