import 'package:flutter_test/flutter_test.dart';

import 'package:marketkita_kurir/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MarketKitaKurirApp());
    await tester.pump();
    expect(find.byType(MarketKitaKurirApp), findsOneWidget);
  });
}
