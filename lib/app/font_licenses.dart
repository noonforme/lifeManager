import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled fonts' licences, EraSans and Noto Sans, to Help ›
/// About › Licenses.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['NotoSans'],
      await rootBundle.loadString('assets/fonts/noto_sans/OFL.txt'),
    );
  });
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/era_sans/LICENSE');
    yield LicenseEntryWithLineBreaks(
      const ['EraSans'],
      "EraSans is Wine's Tahoma-metric font, (C) 2004 Larry Snyder, based on "
      'Bitstream Vera Sans, used under the GNU Lesser General Public License '
      'version 2.1 or later.\n\n$text',
    );
  });
}
