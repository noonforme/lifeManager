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

  test('the Noto Sans licence is registered', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final noto = entries.where((entry) => entry.packages.contains('NotoSans'));
    expect(noto, isNotEmpty);
    final text = noto.first.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('SIL Open Font License'));
  });
}
