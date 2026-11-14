import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bharat_saathi/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const BharatSaathiApp());
  await tester.runAsync(() async { await Future<void>.delayed(const Duration(seconds: 2)); });
  await tester.pump();
}
Future<void> flushStorage(WidgetTester tester) async {
  await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 300)); });
  await tester.pump();
}
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    sqflite.databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    await LocalStore.clear();
  });
  tearDown(() { SharedPreferencesAsyncPlatform.instance = null; });

  testWidgets('Home shows the four requested service icons and no inventory navigation', (tester) async {
    await pumpApp(tester);
    expect(find.text('आपका हिसाब, एक ही जगह'), findsOneWidget);
    expect(find.text('खाता बुक'), findsOneWidget);
    expect(find.text('मोबाइल रिचार्ज'), findsOneWidget);
    expect(find.text('बिल पेमेंट'), findsOneWidget);
    expect(find.text('चालान पेमेंट'), findsOneWidget);
    expect(find.text('स्टॉक'), findsNothing);
    expect(find.text('बिक्री'), findsNothing);
  });

  testWidgets('Bill payment opens the full list of bill categories', (tester) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(find.text('बिल पेमेंट'), 180, scrollable: find.byType(ListView).first);
    await tester.tap(find.text('बिल पेमेंट'));
    await tester.pumpAndSettle();
    for (final item in ['बिजली बिल','पानी बिल','गैस बिल','DTH रिचार्ज','ब्रॉडबैंड / इंटरनेट बिल','लैंडलाइन बिल']) {
      expect(find.text(item), findsOneWidget);
    }
    expect(find.text('COMING SOON'), findsNWidgets(6));
  });

  testWidgets('Recharge and challan categories open their sub-options', (tester) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(find.text('मोबाइल रिचार्ज'), 180, scrollable: find.byType(ListView).first);
    await tester.tap(find.text('मोबाइल रिचार्ज'));
    await tester.pumpAndSettle();
    expect(find.text('प्रीपेड मोबाइल रिचार्ज'), findsOneWidget);
    expect(find.text('पोस्टपेड मोबाइल बिल'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('चालान पेमेंट'), 180, scrollable: find.byType(ListView).first);
    await tester.tap(find.text('चालान पेमेंट'));
    await tester.pumpAndSettle();
    expect(find.text('ट्रैफिक चालान'), findsOneWidget);
    expect(find.text('वाहन चालान की स्थिति'), findsOneWidget);
  });

  testWidgets('Personal khata records a loan and shows the outstanding amount', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('खाता'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('पर्सनल उधार'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('उधार दें'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'दोस्त');
    await tester.enterText(find.byType(TextField).at(1), '2500');
    await tester.tap(find.text('सेव करें'));
    await tester.pumpAndSettle();
    expect(find.text('दोस्त'), findsOneWidget);
    expect(find.text('₹2,500'), findsOneWidget);
  });

  testWidgets('Monthly expense can be recorded', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('खर्च'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('खर्च जोड़ें'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'बिजली');
    await tester.enterText(find.byType(TextField).at(1), '900');
    await tester.tap(find.text('सेव करें'));
    await tester.pumpAndSettle();
    await flushStorage(tester);
    expect(find.text('बिजली'), findsOneWidget);
    expect(find.text('₹900'), findsOneWidget);
  });

  testWidgets('Profile has only Hindi and English and no UPI or OTP option', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    expect(find.text('हिंदी'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<bool>));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('UPI / मनी ट्रांसफर'), findsNothing);
    expect(find.text('मोबाइल OTP / SMS अलर्ट'), findsNothing);
    expect(find.text('WhatsApp: 6283398317'), findsOneWidget);
  });

  testWidgets('Local SQLite records survive app restart', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('खर्च'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('खर्च जोड़ें'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'दूध');
    await tester.enterText(find.byType(TextField).at(1), '100');
    await tester.tap(find.text('सेव करें'));
    await tester.pumpAndSettle();
    await flushStorage(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester);
    await tester.tap(find.text('खर्च'));
    await tester.pumpAndSettle();
    expect(find.text('दूध'), findsOneWidget);
  });
}
