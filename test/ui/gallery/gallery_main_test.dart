import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/startup_mode.dart';
import 'package:lifeos/ui/gallery/gallery_app.dart';
import 'package:lifeos/ui/gallery/gallery_main.dart';

void main() {
  test('only the exact launcher value 1 selects the gallery', () {
    expect(isGalleryRequested('1'), isTrue);
    for (final other in ['', '0', 'true', 'yes', ' 1', '1 ']) {
      expect(isGalleryRequested(other), isFalse, reason: "'$other'");
    }
  });

  test(
    'startup executes only the mode selected by the launcher define',
    () async {
      const expectedGallery = String.fromEnvironment('LIFEOS_GALLERY') == '1';
      final calls = <String>[];
      await startSelectedMode(
        startGallery: () async => calls.add('gallery'),
        startProduction: () async {
          if (expectedGallery) fail('Gallery reached production startup');
          calls.add('production');
        },
      );
      expect(calls, [expectedGallery ? 'gallery' : 'production']);
    },
  );

  test('main wires the isolated gallery and production callbacks', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('startSelectedMode('));
    expect(source, contains('startGallery: _startGallery'));
    expect(source, contains('startProduction: _startProduction'));
    expect(source, isNot(contains('_startWorkShell')));
    expect(source, isNot(contains('LIFEOS_WORK_SHELL')));
    expect(source, isNot(contains('ScratchDatabaseLocation')));
    final galleryStart = source.indexOf('Future<void> _startGallery()');
    final productionStart = source.indexOf('Future<void> _startProduction()');
    expect(galleryStart, isNonNegative);
    expect(productionStart, greaterThan(galleryStart));
    final gallery = source.substring(galleryStart, productionStart);
    expect(gallery, contains('runGallery('));
    expect(gallery, isNot(contains('bootstrap(')));
    expect(gallery, isNot(contains('DatabaseService')));
  });

  test(
    'runGallery prepares the window, mounts the gallery, then shows it',
    () async {
      final calls = <String>[];
      Widget? mounted;
      await runGallery(
        prepareWindow: () async => calls.add('prepare'),
        showWindow: () async => calls.add('show'),
        mount: (app) {
          calls.add('mount');
          mounted = app;
        },
      );
      expect(calls, ['prepare', 'mount', 'show']);
      expect(mounted, isA<GalleryApp>());
    },
  );

  test('production opens the Work shell on the real database under the '
      'trailing-frame binding, with a guarded close beside its place file', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _startProduction()');
    expect(start, isNonNegative);
    final end = source.indexOf('\n}\n', start);
    final production = source.substring(start, end);
    expect(production, contains('bootstrap('));
    expect(production, contains('TrailingFrameBinding()'));
    expect(production, contains('WorkShell('));
    expect(production, contains('WindowManagerCloseApi()'));
    expect(production, contains('FileLocationStore.beside('));
    expect(production, contains('DatabaseConfig.production()'));
  });
}
