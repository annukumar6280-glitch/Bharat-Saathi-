import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bharat_saathi/soundbox_page.dart';

const soundBoxChannel = MethodChannel('bharat_saathi/soundbox');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var hasAccess = false;
  var soundEnabled = true;
  var history = '[]';

  setUp(() {
    hasAccess = false;
    soundEnabled = true;
    history = '[]';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      soundBoxChannel,
      (call) async {
        switch (call.method) {
          case 'hasNotificationAccess':
            return hasAccess;
          case 'getEnabled':
            return soundEnabled;
          case 'getHistory':
            return history;
          case 'getLanguage':
            return 'hi';
          case 'getSpeechRate':
            return 1.0;
          case 'openNotificationSettings':
            return true;
          case 'setEnabled':
            soundEnabled = (call.arguments as Map)['enabled'] as bool;
            return true;
          case 'setLanguage':
          case 'setSpeechRate':
          case 'testSpeech':
          case 'clearHistory':
            return true;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(soundBoxChannel, null);
  });

  testWidgets('asks user to grant notification access', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SoundBoxPage()));
    await tester.pumpAndSettle();
    expect(find.text('Notification Access की अनुमति दें'), findsOneWidget);
    expect(find.textContaining('Notification Access की अनुमति बाकी'), findsOneWidget);
  });

  testWidgets('Sound Box ON/OFF switch stays usable before notification permission is granted', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SoundBoxPage()));
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsOneWidget);
    expect(find.textContaining('Notification Access की अनुमति बाकी'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(soundEnabled, isFalse);
    expect(find.textContaining('Sound Box OFF है'), findsOneWidget);
  });

  testWidgets('refreshes notification permission when app resumes from Android settings', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SoundBoxPage()));
    await tester.pumpAndSettle();
    expect(find.text('Notification Access की अनुमति दें'), findsOneWidget);

    hasAccess = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Notification Access सेटिंग खोलें'), findsOneWidget);
    expect(find.textContaining('Notification Access चालू'), findsOneWidget);
  });

  testWidgets('shows locally stored payment alerts', (tester) async {
    hasAccess = true;
    history = '[{"amount":500,"source":"PhonePe","message":"₹500 received from customer","timestamp":1795680000000}]';
    await tester.pumpWidget(const MaterialApp(home: SoundBoxPage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('₹500 प्राप्ति अलर्ट'), 300);
    expect(find.text('₹500 प्राप्ति अलर्ट'), findsOneWidget);
    expect(find.textContaining('₹500 received from customer'), findsOneWidget);
  });
}
