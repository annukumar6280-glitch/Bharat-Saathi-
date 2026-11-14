import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bharat_saathi/main.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });
  testWidgets('Bharat Saathi home screen renders without seeded demo records', (tester) async {
    await tester.pumpWidget(const BharatSaathiApp());
    await tester.pumpAndSettle();
    expect(find.text('आपका बिजनेस डैशबोर्ड'), findsOneWidget);
    expect(find.text('● ऑफलाइन'), findsOneWidget);
    expect(find.text('● DEMO'), findsNothing);
  });

  testWidgets('Personal finance tab opens', (tester) async {
    await tester.pumpWidget(const BharatSaathiApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('पर्सनल'));
    await tester.pumpAndSettle();
    expect(find.text('पर्सनल फाइनेंस'), findsOneWidget);
    expect(find.text('आय जोड़ें'), findsOneWidget);
    expect(find.text('खर्च जोड़ें'), findsOneWidget);
  });

  testWidgets('Reports page summarizes local records and explains export limits', (tester) async {
    await tester.pumpWidget(const BharatSaathiApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('रिपोर्ट और डेटा एक्सपोर्ट'));
    await tester.pumpAndSettle();
    expect(find.text('रिपोर्ट और एक्सपोर्ट'), findsOneWidget);
    expect(find.text('CSV रिपोर्ट कॉपी करें'), findsOneWidget);
    expect(find.textContaining('तारीख-वार रिपोर्ट और PDF अभी उपलब्ध नहीं हैं'), findsOneWidget);
  });

  testWidgets('Provider-dependent services are clearly marked Coming Soon', (tester) async {
    await tester.pumpWidget(const BharatSaathiApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    final serviceText = find.text('मोबाइल / DTH / FASTag रिचार्ज');
    final serviceRow = find.ancestor(of: serviceText, matching: find.byType(InkWell)).first;
    await tester.ensureVisible(serviceRow);
    await tester.pumpAndSettle();
    await tester.tap(serviceRow);
    await tester.pumpAndSettle();
    expect(find.text('COMING SOON'), findsOneWidget);
  });
}
