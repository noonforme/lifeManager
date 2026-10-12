import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

const _body =
    'Permission is hereby granted, free of charge, to any person obtaining a '
    'copy of this synthetic software, to deal in it without restriction.';

Future<List<LicenceEntry>> _syntheticLicences() async => const [
  LicenceEntry(packages: ['synthetic_core'], text: _body),
  LicenceEntry(
    packages: ['synthetic_ui', 'synthetic_icons'],
    text: '$_body\n\n$_body',
  ),
  LicenceEntry(packages: ['Synthetic Sans (font)'], text: _body),
];

Future<List<LicenceEntry>> _longLicences() async => [
  for (var i = 1; i <= 12; i++)
    LicenceEntry(
      packages: ['synthetic_package_$i'],
      text: '$_body\n\n$_body\n\n$_body',
    ),
];

Future<List<LicenceEntry>> _failingLoader() =>
    Future.error(StateError('Synthetic failure.'));

final licencesPageDemo = GalleryDemo(
  id: 'shell/licences_page',
  widget: 'LicencesPage',
  summary:
      'The Licences page: a title, a Back key and read-only licence text on a '
      'fixed synthetic list. Back is a mouse key; Enabled off greys it. Error '
      'shows the failed load with Retry; Long text lists many long entries.',
  size: const Size(480, 320),
  build: (context, knobs) => SizedBox(
    width: 440,
    height: 280,
    child: LicencesPage(
      onBack: knobs.press(() {}),
      loader: knobs.error
          ? _failingLoader
          : knobs.longText
          ? _longLicences
          : _syntheticLicences,
    ),
  ),
);
