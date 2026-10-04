import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the EraSans licence is registered', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final era = entries.where((entry) => entry.packages.contains('EraSans'));
    expect(era, isNotEmpty);
    final text = era.first.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('GNU Lesser General Public License'));
  });
}
