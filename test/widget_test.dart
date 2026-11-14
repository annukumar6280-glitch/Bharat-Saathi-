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

Future<void> pumpDashboardPhone(WidgetTester tester) async {
  // The default widget-test viewport is landscape (800x600), unlike the
  // portrait phone layout. Give the dashboard a realistic phone viewport.
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await pumpApp(tester);
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
    expect(find.text('कमीशन वॉलेट'), findsOneWidget);
    expect(find.textContaining('सीधे UPI / Gateway से होगा'), findsOneWidget);
    expect(find.text('सर्विस वॉलेट'), findsNothing);
    expect(find.text('स्टॉक'), findsNothing);
    expect(find.text('बिक्री'), findsNothing);
  });

  testWidgets('Bill payment opens the full list of bill categories', (tester) async {
    await pumpDashboardPhone(tester);
    await tester.tap(find.text('बिल पेमेंट'));
    await tester.pumpAndSettle();
    for (final item in ['बिजली बिल','पानी बिल','गैस बिल','DTH रिचार्ज','ब्रॉडबैंड / इंटरनेट बिल','लैंडलाइन बिल','FASTag रिचार्ज (Coming Soon)']) {
      expect(find.text(item), findsOneWidget);
    }
    expect(find.text('COMING SOON'), findsNWidgets(7));
  });

  testWidgets('Recharge and challan categories open their sub-options', (tester) async {
    await pumpDashboardPhone(tester);
    await tester.tap(find.text('मोबाइल रिचार्ज'));
    await tester.pumpAndSettle();
    expect(find.text('प्रीपेड मोबाइल रिचार्ज'), findsOneWidget);
    expect(find.text('पोस्टपेड मोबाइल बिल'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('चालान पेमेंट'));
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
    expect(find.textContaining('मोबाइल नंबर रजिस्ट्रेशन में सेव होगा'), findsNothing);
    expect(find.textContaining('खाता बुक व्यक्तिगत/दुकान के हिसाब'), findsNothing);
    expect(find.text('सर्विस वॉलेट और कमाई'), findsNothing);
  });


  testWidgets('Account and Security is first in profile and exposes login and register', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    final account = find.text('अकाउंट और सुरक्षा');
    final language = find.text('भाषा / Language');
    expect(account, findsOneWidget);
    expect(language, findsOneWidget);
    expect(tester.getTopLeft(account).dy, lessThan(tester.getTopLeft(language).dy));
    await tester.tap(account);
    await tester.pumpAndSettle();
    expect(find.text('लॉगिन करें'), findsWidgets);
    expect(find.text('रजिस्टर करें'), findsOneWidget);
  });

  testWidgets('Referral page shows the one-time ₹10 first-success reward and no paid membership', (tester) async {
    await pumpDashboardPhone(tester);
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('रेफर करें और कमाएँ'));
    await tester.tap(find.text('रेफर करें और कमाएँ'));
    await tester.pumpAndSettle();
    expect(find.text('₹10 First Successful Referral Reward'), findsOneWidget);
    expect(find.textContaining('Level 2'), findsNothing);
    expect(find.textContaining('Lifetime'), findsNothing);
    expect(find.textContaining('₹299'), findsNothing);
  });

  testWidgets('Commission page has no lifetime membership purchase option', (tester) async {
    await pumpDashboardPhone(tester);
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('कमीशन लिस्ट'));
    await tester.tap(find.text('कमीशन लिस्ट'));
    await tester.pumpAndSettle();
    expect(find.text('कमीशन लिस्ट'), findsOneWidget);
    expect(find.textContaining('Subscribe Now'), findsNothing);
    expect(find.textContaining('Lifetime'), findsNothing);
    expect(find.textContaining('₹299'), findsNothing);
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