import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/licenses_dialog.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

void main() {
  testWidgets('lists each package with its licence text', (tester) async {
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks([
          'SyntheticPackage',
        ], 'Synthetic terms.'),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: LifeOSSkinScope(child: Scaffold(body: LicensesDialog())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Licenses'), findsOneWidget);
    expect(find.bySemanticsLabel('Licenses'), findsOneWidget);
    expect(find.text('SyntheticPackage'), findsOneWidget);
    expect(find.textContaining('Synthetic terms.'), findsOneWidget);
  });
}
