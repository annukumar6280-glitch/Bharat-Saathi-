import 'package:flutter_test/flutter_test.dart';
import 'package:bharat_saathi/main.dart';

void main() {
  testWidgets('Bharat Saathi home screen renders', (tester) async {
    await tester.pumpWidget(const BharatSaathiApp());
    await tester.pumpAndSettle();
    expect(find.text('भारत साथी'), findsOneWidget);
  });
}
