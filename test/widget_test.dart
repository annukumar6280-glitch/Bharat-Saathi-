import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bharat_saathi/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const BharatSaathiApp());
  await tester.runAsync(() async { await Future<void>.delayed(const Duration(seconds: 5)); });
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
  testWidgets('Production auth gate shows login before any app page when signed out', (tester) async {
    await tester.pumpWidget(const BharatSaathiApp(requireAuth: true, supabaseAvailable: false));
    await tester.pumpAndSettle();
    expect(find.text('अकाउंट और सुरक्षा'), findsOneWidget);
    expect(find.text('आपका खाता'), findsNothing);
    expect(find.text('बिल पेमेंट'), findsNothing);
    expect(find.text('मोबाइल नंबर (10 अंक)'), findsOneWidget);
  });

  testWidgets('Registration shows legal consent links and consent checkbox', (tester) async {
    await tester.pumpWidget(const BharatSaathiApp(requireAuth: true, supabaseAvailable: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('रजिस्टर करें'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(find.text('अकाउंट बनाएं'), findsOneWidget);
    // The login/register switch is covered by the account-security test.
    // Keep this test focused on registration consent state.
  });

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    sqflite.databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    await LocalStore.clear();
    appDarkMode.value = false;
    bannerAdsEnabled = false;
  });
  tearDown(() { SharedPreferencesAsyncPlatform.instance = null; bannerAdsEnabled = true; });

  test('Local snapshots are isolated by signed-in user ID', () async {
    await LocalStore.write('account-a', '{"cash":100}');
    await LocalStore.write('account-b', '{"cash":250}');
    expect(await LocalStore.read('account-a'), '{"cash":100}');
    expect(await LocalStore.read('account-b'), '{"cash":250}');
  });

  test('Retired inventory fields are stripped from every local snapshot', () async {
    await LocalStore.write('account-a', '{"cash":100,"products":[{"name":"old"}],"sales":[{"amount":20}],"purchases":[{"amount":10}],"supplierLedger":[],"salesReturns":[],"stockAdjustments":[]}');
    final db = await LocalStore.database;
    await db.execute('CREATE TABLE IF NOT EXISTS legacy_app_state (id INTEGER PRIMARY KEY, payload TEXT NOT NULL, updated_at TEXT NOT NULL)');
    await db.insert('legacy_app_state', {
      'id': 1,
      'payload': '{"cash":75,"products":[{"name":"legacy"}],"sales":[]}',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    final preferences = await LocalStore.sanitizeLegacyInventoryData(
      '{"cash":50,"products":[{"name":"prefs"}],"purchases":[]}',
    );

    final account = jsonDecode((await LocalStore.read('account-a'))!) as Map<String, dynamic>;
    final legacyRows = await db.query('legacy_app_state', columns: ['payload']);
    final legacy = jsonDecode(legacyRows.single['payload'] as String) as Map<String, dynamic>;
    final prefs = jsonDecode(preferences!) as Map<String, dynamic>;

    expect(account, {'cash': 100});
    expect(legacy, {'cash': 75});
    expect(prefs, {'cash': 50});
  });

  test('Empty legacy preference is not treated as an old snapshot', () async {
    expect(await LocalStore.hasUnassignedLegacyData(''), isFalse);
    expect(await LocalStore.migrateLegacyForUser('account-a', ''), isTrue);
    expect(await LocalStore.read('account-a'), isNull);
  });

  test('Legacy local snapshot requires explicit account confirmation', () async {
    await LocalStore.declineLegacyForUser('account-a');
    expect(await LocalStore.wasLegacyDeclinedForUser('account-a'), isTrue);
    expect(await LocalStore.wasLegacyDeclinedForUser('account-b'), isFalse);
    expect(await LocalStore.hasUnassignedLegacyData('{"cash":75}'), isTrue);
    await LocalStore.migrateLegacyForUser('account-b', '{"cash":75}');
    expect(await LocalStore.read('account-a'), isNull);
    expect(await LocalStore.read('account-b'), '{"cash":75}');
    expect(await LocalStore.hasUnassignedLegacyData('{"cash":75}'), isFalse);
  });

  test('Legacy import never overwrites existing account records', () async {
    await LocalStore.write('account-a', '{"cash":100}');
    expect(await LocalStore.migrateLegacyForUser('account-a', '{"cash":75}'), isFalse);
    expect(await LocalStore.read('account-a'), '{"cash":100}');
    expect(await LocalStore.hasUnassignedLegacyData('{"cash":75}'), isTrue);
    expect(await LocalStore.migrateLegacyForUser('account-b', '{"cash":75}'), isTrue);
    expect(await LocalStore.read('account-a'), '{"cash":100}');
    expect(await LocalStore.read('account-b'), '{"cash":75}');
  });

  testWidgets('Home shows the retained modules and six new shopkeeper tools', (tester) async {
    await pumpDashboardPhone(tester);
    expect(find.text('आपका खाता'), findsOneWidget);
    expect(find.text('खाता बुक'), findsOneWidget);
    expect(find.text('बिल / सामान लिस्ट'), findsOneWidget);
    for (final title in ['QR Code Tools','Poster Maker','Reminders & Notes','Smart Calculator','Payment Sound Box','AI Calling Assistant']) {
      await tester.ensureVisible(find.text(title));
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('मोबाइल रिचार्ज'), findsNothing);
    expect(find.text('बिल पेमेंट'), findsNothing);
    expect(find.text('चालान पेमेंट'), findsNothing);
    expect(find.text('बाइक / कार इंश्योरेंस'), findsNothing);
    expect(find.text('कमीशन वॉलेट'), findsNothing);
  });

  testWidgets('QR tools open and render QR generation and scanner action', (tester) async {
    await pumpDashboardPhone(tester);
    await tester.ensureVisible(find.text('QR Code Tools'));
    await tester.tap(find.text('QR Code Tools'));
    await tester.pumpAndSettle();
    expect(find.text('QR कोड बनाएँ'), findsOneWidget);
    expect(find.text('QR स्कैन करें'), findsOneWidget);
  });

  testWidgets('Business calculator exposes GST, discount and profit calculations', (tester) async {
    await pumpDashboardPhone(tester);
    await tester.ensureVisible(find.text('Smart Calculator'));
    await tester.tap(find.text('Smart Calculator'));
    await tester.pumpAndSettle();
    expect(find.text('GST सहित'), findsOneWidget);
    expect(find.text('छूट के बाद'), findsOneWidget);
    expect(find.text('मुनाफा %'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('WhatsApp: 6283398317'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp: 6283398317'), findsOneWidget);
    expect(find.textContaining('मोबाइल नंबर रजिस्ट्रेशन में सेव होगा'), findsNothing);
    expect(find.textContaining('खाता बुक व्यक्तिगत/दुकान के हिसाब'), findsNothing);
    expect(find.text('सर्विस वॉलेट और कमाई'), findsNothing);
  });


  testWidgets('Banner ads are excluded from Home and placed on History and Profile', (tester) async {
    await pumpDashboardPhone(tester);
    expect(find.byType(BannerAdSlot), findsNothing);
    await tester.tap(find.text('इतिहास'));
    await tester.pumpAndSettle();
    expect(find.byType(BannerAdSlot), findsOneWidget);
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    expect(find.byType(BannerAdSlot), findsOneWidget);
  });

  testWidgets('Transaction History is available in the bottom navigation', (tester) async {
    await pumpDashboardPhone(tester);
    await tester.tap(find.text('इतिहास'));
    await tester.pumpAndSettle();
    expect(find.text('ट्रांजैक्शन हिस्ट्री'), findsOneWidget);
    expect(find.text('अभी कोई ट्रांजैक्शन नहीं है'), findsOneWidget);
  });

  testWidgets('Dark theme switch changes the app theme', (tester) async {
    await pumpDashboardPhone(tester);
    await tester.tap(find.text('प्रोफाइल'));
    await tester.pumpAndSettle();
    expect(find.text('डार्क थीम'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(NavigationBar))).brightness, Brightness.dark);
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