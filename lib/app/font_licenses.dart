import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled EraSans font's licence to Help › About › Licenses.
void registerFontLicenses() {
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
