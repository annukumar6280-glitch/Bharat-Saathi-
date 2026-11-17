import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bharat_saathi/main.dart';

void main() {
  test('Bill line totals multiply quantity by unit price', () {
    expect(calculateBillLineTotal(2, 50), 100);
    expect(calculateBillLineTotal(3, 40), 120);
  });

  test('Bill grand total adds all calculated item totals', () {
    expect(calculateBillTotal([100, 120]), 220);
    expect(calculateBillTotal([]), 0);
  });

  testWidgets('Bill mode calculates quantity times unit price', (tester) async {
    await tester.pumpWidget(MaterialApp(home: BillListPage()));
    await tester.enterText(find.byType(TextField).at(0), 'Customer');
    await tester.enterText(find.byType(TextField).at(1), '9876543210');
    await tester.tap(find.text('आगे बढ़ें'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Rice');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.enterText(find.byType(TextField).at(2), '50');
    await tester.pump();
    expect(find.text('कुल राशि: ₹100.00'), findsOneWidget);
  });

  testWidgets('Shopping list supports optional price and print/save in both modes', (tester) async {
    await tester.pumpWidget(MaterialApp(home: BillListPage()));
    await tester.enterText(find.byType(TextField).at(0), 'Customer');
    await tester.enterText(find.byType(TextField).at(1), '9876543210');
    await tester.tap(find.text('आगे बढ़ें'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('सामान लिस्ट'));
    await tester.pumpAndSettle();
    expect(find.text('कीमत (वैकल्पिक ₹)'), findsOneWidget);
    final printButton = find.text('प्रिंट / PDF सेव करें');
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(printButton, findsOneWidget);
    await tester.tap(find.text('एक और सामान जोड़ें'));
    await tester.pumpAndSettle();
    expect(find.text('सामान 2'), findsOneWidget);
  });
}
