import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bharat_saathi/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';


Future<void> flushStorage(WidgetTester tester) async {
  await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 400)); });
  await tester.pump();
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const BharatSaathiApp());
  await tester.runAsync(() async { await Future<void>.delayed(const Duration(seconds: 3)); });
  await tester.pump();
}

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; sqflite.databaseFactory = databaseFactoryFfi; });
  setUp(() async { SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty(); await LocalStore.clear(); });
  tearDown(() { SharedPreferencesAsyncPlatform.instance = null; });
  testWidgets('Bharat Saathi home screen renders without seeded demo records', (tester) async {
    await pumpApp(tester);
    expect(find.text('आपका बिजनेस डैशबोर्ड'), findsOneWidget);
    expect(find.text('● ऑफलाइन'), findsOneWidget);
    expect(find.text('● DEMO'), findsNothing);
  });

  testWidgets('Personal finance tab opens', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('पर्सनल'));
    await tester.pumpAndSettle();
    expect(find.text('पर्सनल फाइनेंस'), findsOneWidget);
    expect(find.text('आय जोड़ें'), findsOneWidget);
    expect(find.text('खर्च जोड़ें'), findsOneWidget);
  });

  testWidgets('Reports page summarizes local records and explains export limits', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('रिपोर्ट और डेटा एक्सपोर्ट'));
    await tester.pumpAndSettle();
    expect(find.text('रिपोर्ट और एक्सपोर्ट'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('CSV रिपोर्ट डाउनलोड / शेयर करें'), 200);
    expect(find.text('CSV रिपोर्ट डाउनलोड / शेयर करें'), findsOneWidget);
    expect(find.text('तारीख़ के अनुसार फ़िल्टर करें'), findsOneWidget);
  });

  testWidgets('Provider-dependent services are clearly marked Coming Soon', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('मोबाइल / DTH / FASTag रिचार्ज'), 200);
    expect(find.text('Coming Soon • स्वीकृत प्रदाता API आवश्यक'), findsOneWidget);
  });

  testWidgets('Retailer purchase records supplier and increases stock', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('स्टॉक'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('प्रोडक्ट'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'चावल');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.enterText(find.byType(TextField).at(2), '100');
    await tester.tap(find.text('प्रोडक्ट सेव करें'));
    await tester.pumpAndSettle();
    await flushStorage(tester);

    await tester.tap(find.text('खरीद दर्ज करें'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ABC सप्लायर');
    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.enterText(find.byType(TextField).at(2), '70');
    await tester.tap(find.text('खरीद सेव करें'));
    await tester.pumpAndSettle();
    await flushStorage(tester);

    expect(find.text('ABC सप्लायर'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('SQLite-backed local records survive app restart', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('स्टॉक'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('प्रोडक्ट'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'टेस्ट आटा');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.enterText(find.byType(TextField).at(2), '45');
    await tester.tap(find.text('प्रोडक्ट सेव करें'));
    await tester.pumpAndSettle();
    await flushStorage(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester);
    await tester.tap(find.text('स्टॉक'));
    await tester.pumpAndSettle();
    expect(find.text('टेस्ट आटा'), findsOneWidget);
  });

  testWidgets('Supplier credit purchase creates payable balance', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('स्टॉक'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('प्रोडक्ट'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'दाल');
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.enterText(find.byType(TextField).at(2), '80');
    await tester.tap(find.text('प्रोडक्ट सेव करें'));
    await tester.pumpAndSettle();
    await flushStorage(tester);

    await tester.tap(find.text('खरीद दर्ज करें'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'सप्लायर एक');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.enterText(find.byType(TextField).at(2), '40');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('सप्लायर से उधार').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('खरीद सेव करें'));
    await tester.pumpAndSettle();
    await flushStorage(tester);

    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('रिपोर्ट और डेटा एक्सपोर्ट'));
    await tester.pumpAndSettle();
    expect(find.text('सप्लायर बकाया'), findsOneWidget);
    expect(find.text('₹80'), findsNWidgets(2));
  });

  testWidgets('Sales return restores stock and records refund', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('स्टॉक'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('प्रोडक्ट'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'तेल');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.enterText(find.byType(TextField).at(2), '100');
    await tester.tap(find.text('प्रोडक्ट सेव करें'));
    await tester.pumpAndSettle();
    await flushStorage(tester);

    await tester.tap(find.text('बिक्री').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'बिक्री'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ग्राहक एक');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.tap(find.text('बिक्री सेव करें'));
    await tester.pumpAndSettle();
    await flushStorage(tester);

    await tester.tap(find.text('बिक्री वापसी दर्ज करें'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ग्राहक एक');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.tap(find.text('वापसी सेव करें'));
    await tester.pumpAndSettle();
    await flushStorage(tester);

    await tester.tap(find.text('स्टॉक'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
  });
}
