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

  testWidgets('Provider-dependent services are clearly marked Coming Soon', (tester) async {
    await tester.pumpWidget(const BharatSaathiApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('मोबाइल / DTH / FASTag रिचार्ज'), 200);
    await tester.tap(find.text('मोबाइल / DTH / FASTag रिचार्ज'));
    await tester.pumpAndSettle();
    expect(find.text('COMING SOON'), findsOneWidget);
  });
}
