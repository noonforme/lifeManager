import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/property_sheet.dart';

void main() {
  test('apply runs only when dirty and clears dirty after a save', () async {
    final sheet = PropertySheetController();
    addTearDown(sheet.dispose);
    var saves = 0;
    Future<bool> save() async {
      saves++;
      return true;
    }

    sheet.attach(apply: save);
    expect(await sheet.apply(), isTrue);
    expect(saves, 0);
    sheet.markDirty(true);
    expect(await sheet.apply(), isTrue);
    expect(saves, 1);
    expect(sheet.dirty, isFalse);
  });

  test('a failed save stays dirty', () async {
    final sheet = PropertySheetController()..attach(apply: () async => false);
    addTearDown(sheet.dispose);
    sheet.markDirty(true);
    expect(await sheet.apply(), isFalse);
    expect(sheet.dirty, isTrue);
  });

  test('a detached sheet has nothing to apply', () async {
    final sheet = PropertySheetController();
    addTearDown(sheet.dispose);
    Future<bool> save() async => false;
    sheet
      ..attach(apply: save)
      ..markDirty(true)
      ..detach(save);
    expect(sheet.dirty, isFalse);
    expect(await sheet.apply(), isTrue);
  });
}
