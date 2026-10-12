import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/data_grid_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

import 'data_grid_harness.dart';

const dataGridVariantCanvas = ValueKey('data-grid-variant-canvas');

/// A bounded desktop viewport, including root-overlay popups. The 200%
/// variant keeps this same physical size rather than enlarging the demo.
Future<void> pumpDataGridVariant(
  WidgetTester tester,
  GalleryKnobs knobs,
) async {
  tester.view.physicalSize = dataGridDemo.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: dataGridVariantCanvas,
      child: GalleryHost(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(knobs.textScale)),
            child: EraFormScope(
              enabled: knobs.enabled,
              child: ColoredBox(
                color: MillenniumColors.page,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: dataGridDemo.build(context, knobs),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _asIs(WidgetTester tester) async {}

Future<void> _rejectBreak(WidgetTester tester) async {
  await click(tester, gridCell('d7', 'break'));
  await tester.enterText(find.byType(EditableText), '0:xx');
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  expect(find.text('Enter a break like 0:30.'), findsOneWidget);
}

Future<void> _openChoice(WidgetTester tester) async {
  await click(tester, gridCell('d7', 'type'));
  await click(
    tester,
    find.descendant(of: find.byType(CellEditor), matching: find.text('Day')),
  );
  expect(
    find.widgetWithText(MenuItemButton, 'Vacation').hitTestable(),
    findsOneWidget,
  );
}

Future<void> _pickRows(WidgetTester tester) async {
  await click(tester, find.text('Pick days…'));
  await click(tester, find.byKey(const ValueKey('grid-pick:d6')));
  await click(tester, find.byKey(const ValueKey('grid-pick:d7')));
  expect(find.text('Total (2 picked)'), findsOneWidget);
  expect(find.text('23:45'), findsOneWidget);
}

final dataGridVariants =
    <(String, GalleryKnobs, Future<void> Function(WidgetTester))>[
      (
        'data_data_grid_disabled_error',
        const GalleryKnobs(enabled: false, error: true, longText: true),
        _asIs,
      ),
      ('data_data_grid_rejected', const GalleryKnobs(), _rejectBreak),
      ('data_data_grid_open_choice', const GalleryKnobs(), _openChoice),
      (
        'data_data_grid_200',
        const GalleryKnobs(textScale: 2, error: true, longText: true),
        _asIs,
      ),
      ('data_data_grid_picked', const GalleryKnobs(), _pickRows),
    ];
