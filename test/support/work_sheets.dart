import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the Work View combo and picks [sheet] ("Shifts", "Pay periods",
/// "Payslips" or "Agreements").
Future<void> chooseSheet(WidgetTester tester, String sheet) async {
  await tester.tap(find.byKey(const ValueKey('work-view-combo')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(sheet).last);
  await tester.pumpAndSettle();
}
