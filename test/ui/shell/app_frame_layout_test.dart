import 'package:flutter/material.dart' show TextButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart';

/// AppFrame (database shell spec 3, 4.1, 4.4, 4.6) composed of the real
/// library widgets on synthetic data: breakpoints by client width, scaled
/// minima, one instance of each pane moved (never rebuilt) between column,
/// overlay, docked tab and park, owner-held per-area sizes scaled once,
/// bounded chrome, and every editor, popup, error and command reachable
/// across the layout matrix at 100 and 200 % text.
void main() {
  group('AppFrameLayout.resolve', () {
    for (final (width, scale, folded, docked) in [
      (1280.0, 1.0, false, false),
      (1025.0, 1.0, false, false),
      // The client width decides: the page padding does not fold 1024.
      (1024.0, 1.0, false, false),
      (1023.0, 1.0, true, false),
      (960.0, 1.0, true, false),
      (861.0, 1.0, true, false),
      (860.0, 1.0, true, false),
      (859.0, 1.0, true, true),
      (800.0, 1.0, true, true),
      // At 200 % the scaled minima fold and dock earlier.
      (1280.0, 2.0, true, false),
      (1025.0, 2.0, true, true),
      (1024.0, 2.0, true, true),
      (800.0, 2.0, true, true),
      // Above the breakpoints, when the minima do not fit.
      (1100.0, 1.75, true, false),
      (900.0, 1.75, true, true),
    ]) {
      test('$width px at ${scale * 100} %: folded $folded, docked $docked', () {
        final layout = AppFrameLayout.resolve(width: width, scale: scale);
        expect(layout.treeFolded, folded);
        expect(layout.propertiesDocked, docked);
        final inner = width - 2 * AppFrame.pagePadding - EraScrollbar.thickness;
        final used =
            layout.left +
            layout.right +
            (folded ? 0 : Splitter.thickness) +
            (docked ? 0 : Splitter.thickness);
        expect(
          inner - used,
          greaterThanOrEqualTo(AppFrame.minMiddle * scale - 0.01),
          reason: 'the grid keeps its scaled minimum',
        );
      });
    }

    test('baseline sizes are scaled once, folded narrows toward 260', () {
      final wide = AppFrameLayout.resolve(width: 2600, scale: 2);
      expect(wide.treeFolded, isFalse);
      expect(wide.left, 392);
      expect(wide.right, 612);
      expect(AppFrameLayout.resolve(width: 1280, scale: 1).left, 196);
      expect(AppFrameLayout.resolve(width: 1280, scale: 1).right, 306);
      expect(AppFrameLayout.resolve(width: 1023, scale: 1).right, 260);
      expect(AppFrameLayout.resolve(width: 1280, scale: 2).right, 520);
    });

    test('extreme restored sizes are clamped, not trusted', () {
      for (final panes in const [
        AppFramePanes(left: 1e9, right: 1e9, dock: 1e9),
        AppFramePanes(left: -50, right: 0, dock: -10),
        AppFramePanes(
          left: double.infinity,
          right: double.negativeInfinity,
          dock: double.nan,
        ),
        AppFramePanes(left: double.nan, right: double.nan, dock: 0),
      ]) {
        for (final (width, scale) in [(1280.0, 1.0), (2600.0, 2.0)]) {
          final layout = AppFrameLayout.resolve(
            width: width,
            scale: scale,
            panes: panes,
          );
          expect(layout.left, inInclusiveRange(140 * scale, layout.leftMax));
          expect(layout.right, inInclusiveRange(220 * scale, layout.rightMax));
          expect(
            width - 4 - 17 - layout.left - layout.right - 10,
            greaterThanOrEqualTo(320 * scale - 0.01),
          );
          for (final height in [600.0, 200.0, 0.0]) {
            final (lower, least, most) = layout.lowerHeight(height, panes);
            expect(lower, inInclusiveRange(least, most), reason: '$panes');
            expect(lower.isFinite, isTrue);
          }
        }
      }
      final nan = AppFrameLayout.resolve(
        width: 1280,
        scale: 1,
        panes: const AppFramePanes(left: double.nan, right: double.nan),
      );
      expect((nan.left, nan.right), (196, 306));
    });
  });

  group('breakpoints in the real frame', () {
    for (final (width, scale) in [
      (1025.0, 1.0),
      (1024.0, 1.0),
      (1023.0, 1.0),
      (861.0, 1.0),
      (860.0, 1.0),
      (859.0, 1.0),
      (1280.0, 2.0),
      (1024.0, 2.0),
    ]) {
      testWidgets('$width px at ${scale * 100} %', (tester) async {
        await pumpAppFrame(tester, Size(width, 768), scale: scale);
        final layout = AppFrameLayout.resolve(width: width, scale: scale);
        expect(treeColumn, layout.treeFolded ? findsNothing : findsOneWidget);
        expect(treeKey, layout.treeFolded ? findsOneWidget : findsNothing);
        expect(
          propertyColumn,
          layout.propertiesDocked ? findsNothing : findsOneWidget,
        );
        expect(
          dockTab(),
          layout.propertiesDocked ? findsOneWidget : findsNothing,
        );
        if (!layout.treeFolded) {
          expect(tester.getSize(treeColumn).width, layout.left);
        }
        if (!layout.propertiesDocked) {
          expect(tester.getSize(propertyColumn).width, layout.right);
        }
        // Exactly one tree pane and one property grid exist at any width.
        expect(find.byType(TreeView, skipOffstage: false), findsOneWidget);
        expect(find.byType(PropertyGrid, skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('owner-held sizes', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${scale * 100} %: splitters report baseline sizes', (
        tester,
      ) async {
        final size = Size(1280 * scale + 400, 800 * scale);
        final showcase = await pumpAppFrame(tester, size, scale: scale);
        expect(tester.getSize(treeColumn).width, 196 * scale);
        expect(tester.getSize(propertyColumn).width, 306 * scale);

        await drag(tester, splitter('left'), const Offset(40, 0));
        expect(showcase.panes['work']!.left, 196 + 40 / scale);
        expect(tester.getSize(treeColumn).width, 196 * scale + 40);
        expect(showcase.events, contains('panes:work'));

        await drag(tester, splitter('right'), const Offset(30, 0));
        expect(showcase.panes['work']!.right, 306 - 30 / scale);
        expect(tester.getSize(propertyColumn).width, 306 * scale - 30);

        final lower = find.byType(Subform);
        final before = tester.getSize(lower).height;
        await drag(tester, splitter('lower'), const Offset(0, -24));
        expect(showcase.panes['work']!.dock, 168 + 24 / scale);
        expect(tester.getSize(lower).height, before + 24);

        // Past every clamp: the grid keeps its minimum width and height.
        await drag(tester, splitter('left'), const Offset(5000, 0));
        await drag(tester, splitter('lower'), const Offset(0, -5000));
        final grid = tester.getSize(dataGrid);
        expect(grid.width, greaterThanOrEqualTo(320 * scale - 0.5));
        expect(
          tester
              .getSize(find.byKey(const ValueKey('app-frame-middle-column')))
              .width,
          greaterThanOrEqualTo(320 * scale - 0.5),
        );
        expect(grid.height, greaterThanOrEqualTo(90 * scale - 0.5));
        expect(tester.takeException(), isNull);
      });

      testWidgets('${scale * 100} %: each area restores its own sizes', (
        tester,
      ) async {
        final size = Size(1280 * scale + 400, 800 * scale);
        final showcase = await pumpAppFrame(tester, size, scale: scale);
        showcase.restorePanes(
          'tracking',
          const AppFramePanes(left: 250, right: 280, dock: 200),
        );
        await click(tester, find.text('Tracking'));
        expect(showcase.area, 'tracking');
        expect(tester.getSize(treeColumn).width, 250 * scale);
        expect(tester.getSize(propertyColumn).width, 280 * scale);
        expect(tester.getSize(find.byType(Subform)).height, 200 * scale);

        await click(tester, find.text('Work'));
        expect(tester.getSize(treeColumn).width, 196 * scale);
        expect(tester.getSize(propertyColumn).width, 306 * scale);
        expect(tester.getSize(find.byType(Subform)).height, 168 * scale);
        // Clamping for a small window never rewrites the owner's sizes.
        showcase.restorePanes(
          'work',
          const AppFramePanes(left: 1e6, right: 1e6, dock: 1e6),
        );
        await tester.pump();
        await resizeTo(tester, Size(1100 * scale, 520 * scale));
        await resizeTo(tester, Size(1100 * scale, 380 * scale));
        expect(showcase.panes['work']!.left, 1e6);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('app-frame-middle-column')))
              .width,
          greaterThanOrEqualTo(320 * scale - 0.5),
        );
      });
    }
  });

  group('one pane instance moves between places', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${scale * 100} %: a property draft survives every '
          'transition with its editor focused, never committed', (
        tester,
      ) async {
        final start = Size(1300 * scale, 800);
        final showcase = await pumpAppFrame(tester, start, scale: scale);
        final grid = tester.state(find.byType(PropertyGrid));
        final data = tester.state(dataGrid);
        final subform = tester.state(find.byType(Subform));
        await click(tester, propertyValue('note'));
        await tester.enterText(propertyEditor('note'), 'Swapped with Ann');
        await tester.pump();
        final events = [...showcase.events];

        for (final width in [
          1025.0,
          1023.0,
          861.0,
          859.0,
          800.0,
          861.0,
          1024.0,
          1300.0,
          800.0,
        ]) {
          await resizeTo(tester, Size(width * scale, 800));
          final layout = frameOf(tester).layout!;
          final at = '${width * scale} px';
          expect(showcase.controller.session?.draft, 'Swapped with Ann');
          expect(showcase.events, events, reason: '$at: no command');
          expect(tester.state(find.byType(PropertyGrid)), same(grid));
          expect(tester.state(dataGrid), same(data));
          expect(tester.state(find.byType(Subform)), same(subform));
          // The frame revealed the docked tab through the owner.
          expect(
            showcase.subformTab,
            layout.propertiesDocked ? AppFrame.propertiesTabId : 'breaks',
            reason: at,
          );
          expect(focusedIn(tester, propertyEditor('note')), isTrue, reason: at);
          expectHittable(tester, propertyEditor('note'), reason: at);
          expect(tester.takeException(), isNull);
        }
        await press(tester, LogicalKeyboardKey.enter);
        expect(showcase.value('note'), 'Swapped with Ann');
      });

      testWidgets('${scale * 100} %: a grid draft survives folding and '
          'docking', (tester) async {
        final showcase = await pumpAppFrame(
          tester,
          Size(1300 * scale, 800),
          scale: scale,
        );
        await click(tester, await gridCell(tester, 'd7', 'type'));
        final editor = find.byKey(const ValueKey('grid-editor:type'));
        await click(
          tester,
          find.descendant(of: editor, matching: find.text('Day')),
        );
        await click(tester, comboChoice('Night'));
        expect(showcase.controller.session?.draft, 'night');
        for (final width in [1023.0, 859.0, 1300.0]) {
          await resizeTo(tester, Size(width * scale, 800));
          expect(showcase.controller.session?.draft, 'night');
          expect(focusedIn(tester, editor), isTrue);
          expectHittable(tester, editor);
          // The grid region was active: no reveal of the properties.
          expect(showcase.subformTab, 'breaks');
        }
        expect(showcase.events.where((e) => e.startsWith('commit')), isEmpty);
      });
    }

    testWidgets('a cached docked tab hands the pane back without a '
        'duplicate key', (tester) async {
      final showcase = await pumpAppFrame(tester, const Size(800, 600));
      await showProperties(tester);
      final grid = tester.state(find.byType(PropertyGrid));
      // Another child tab: the docked tab's content stays cached.
      await click(tester, dockTab('History'));
      expect(find.byType(PropertyGrid), findsNothing);
      expect(find.byType(PropertyGrid, skipOffstage: false), findsOneWidget);
      await resizeTo(tester, const Size(1280, 800));
      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(PropertyGrid)), same(grid));
      expect(showcase.subformTab, 'history');
      await resizeTo(tester, const Size(800, 600));
      // Not the active region: parked, not revealed.
      expect(showcase.subformTab, 'history');
      expect(find.byType(PropertyGrid), findsNothing);
      expect(
        tester.state(find.byType(PropertyGrid, skipOffstage: false)),
        same(grid),
      );
      await showProperties(tester);
      expect(tester.state(find.byType(PropertyGrid)), same(grid));
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('${scale * 100} %: the grid keeps its scroll offset across '
          'folding and docking', (tester) async {
        await pumpAppFrame(tester, Size(1300 * scale, 900), scale: scale);
        final body = find.descendant(
          of: dataGrid,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        );
        ScrollPosition position() => tester
            .stateList<ScrollableState>(body)
            .map((state) => state.position)
            .firstWhere((position) => position.maxScrollExtent > 0);
        position().jumpTo(60 * scale);
        await tester.pumpAndSettle();
        final scrolled = position().pixels;
        expect(scrolled, 60 * scale);
        for (final width in [1023.0, 859.0, 800.0, 1300.0]) {
          await resizeTo(tester, Size(width * scale, 900));
          expect(position().pixels, scrolled, reason: '$width');
        }
      });
    }

    testWidgets('parked panes take no focus', (tester) async {
      await pumpAppFrame(tester, const Size(800, 600));
      final nodes = find.descendant(
        of: find.byType(PropertyGrid, skipOffstage: false),
        matching: find.byType(Focus, skipOffstage: false),
        skipOffstage: false,
      );
      expect(nodes, findsWidgets);
      for (final element in nodes.evaluate()) {
        Focus.of(element).requestFocus();
      }
      await tester.pump();
      expect(
        focusedIn(tester, find.byType(PropertyGrid, skipOffstage: false)),
        isFalse,
      );
    });
  });

  group('the folded tree', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${scale * 100} %: hangs from the Tree key, bounded, with '
          'Details reachable; Close and outside clicks close it', (
        tester,
      ) async {
        final showcase = await pumpAppFrame(
          tester,
          const Size(960, 700),
          scale: scale,
        );
        final tree = tester.state(find.byType(TreeView, skipOffstage: false));
        expect(find.byType(TreeView), findsNothing);
        await click(tester, treeKey);
        expect(treeOverlay, findsOneWidget);
        final key = tester.getRect(treeKey);
        final overlay = tester.getRect(treeOverlay);
        expect(overlay.top, key.bottom);
        expect((overlay.left - key.left).abs(), lessThanOrEqualTo(2.01));
        final status = tester.getRect(find.byType(StatusBar));
        expect(overlay.bottom, lessThanOrEqualTo(status.top));
        expect(overlay.width, 196 * scale);
        expect(tester.state(find.byType(TreeView)), same(tree));
        // The tree is capped, so Details stays in the overlay.
        final details = find.descendant(
          of: treeOverlay,
          matching: find.text('Details'),
        );
        expectHittable(tester, details);
        await click(tester, find.text('Pay from 2026-10-01'));
        expect(showcase.events, contains('follow:agreement'));
        await click(tester, find.text('Pay periods'));
        expect(showcase.treeId, 'night:periods');
        expect(treeOverlay, findsOneWidget);

        await click(tester, find.bySemanticsLabel('Close the tree'));
        expect(treeOverlay, findsNothing);

        await click(tester, treeKey);
        // Outside the overlay, over the grid or the docked subform.
        final outside = Offset(
          tester.view.physicalSize.width - 40,
          tester.getRect(treeOverlay).center.dy,
        );
        final selected = showcase.selectedId;
        await tester.tapAt(outside);
        await tester.pumpAndSettle();
        expect(treeOverlay, findsNothing);
        expect(showcase.selectedId, selected, reason: 'the click closes only');
        expect(
          tester.state(find.byType(TreeView, skipOffstage: false)),
          same(tree),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a refused draft keeps the tree selection (editor guard)', (
      tester,
    ) async {
      final showcase = await pumpAppFrame(tester, const Size(960, 700));
      await click(tester, propertyValue('note'));
      await tester.enterText(propertyEditor('note'), '');
      await press(tester, LogicalKeyboardKey.enter);
      expect(showcase.controller.session?.error, isNotNull);
      await click(tester, treeKey);
      await click(tester, find.text('Payslips'));
      expect(showcase.treeId, 'night:shifts');
      expect(showcase.controller.session?.error, isNotNull);
    });

    testWidgets('widening while open puts the tree back in its column', (
      tester,
    ) async {
      await pumpAppFrame(tester, const Size(960, 700));
      final tree = tester.state(find.byType(TreeView, skipOffstage: false));
      await click(tester, treeKey);
      await resizeTo(tester, const Size(1280, 800));
      expect(treeOverlay, findsNothing);
      expect(treeColumn, findsOneWidget);
      expect(tester.state(find.byType(TreeView)), same(tree));
      await resizeTo(tester, const Size(960, 700));
      expect(frameOf(tester).treeOpen, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('guards and keyboard', () {
    testWidgets('menus and area tabs flush first and drop the request when '
        'refused', (tester) async {
      final showcase = await pumpAppFrame(tester, const Size(1280, 800));
      await click(tester, propertyValue('note'));
      await tester.enterText(propertyEditor('note'), '');
      await press(tester, LogicalKeyboardKey.enter);
      await click(tester, find.text('Tracking'));
      expect(showcase.area, 'work');
      await click(tester, find.text('Help'));
      await click(tester, find.text('Licences'));
      expect(showcase.events, isNot(contains('menu:Licences')));
      await tester.enterText(propertyEditor('note'), 'Fixed');
      await click(tester, find.text('Tracking'));
      expect(showcase.area, 'tracking');
      expect(showcase.events, contains('commit:d7:note'));
    });

    testWidgets('Tree key, menus and area tabs take no keyboard', (
      tester,
    ) async {
      final showcase = await pumpAppFrame(tester, const Size(960, 700));
      for (final key in [
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.f10,
      ]) {
        await press(tester, key);
      }
      expect(frameOf(tester).treeOpen, isFalse);
      expect(showcase.area, 'work');
      expect(find.text('Licences'), findsNothing);
    });

    testWidgets('Enabled off greys the Tree key, menus, tabs and splitters', (
      tester,
    ) async {
      final showcase = await pumpAppFrame(
        tester,
        const Size(960, 700),
        knobs: const GalleryKnobs(enabled: false),
      );
      expect(tester.widget<KeyButton>(treeKey).onPressed, isNull);
      final menus = tester.widgetList<TextButton>(
        find.descendant(
          of: find.byType(AppFrame),
          matching: find.byType(TextButton),
        ),
      );
      expect(menus, hasLength(7));
      expect(menus.map((menu) => menu.onPressed), everyElement(isNull));
      await tester.tap(find.text('Tracking'));
      await tester.pumpAndSettle();
      expect(showcase.area, 'work');
      await resizeTo(tester, const Size(1280, 800));
      await drag(tester, splitter('left'), const Offset(40, 0));
      expect(showcase.panes, isEmpty);
    });
  });

  group('layout matrix', () {
    for (final scale in [1.0, 2.0]) {
      for (final size in appFrameSizes) {
        testWidgets('${size.width.toInt()} x ${size.height.toInt()} at '
            '${scale * 100} %: every editor, popup, error and command', (
          tester,
        ) async {
          final showcase = await pumpAppFrame(tester, size, scale: scale);
          final layout = frameOf(tester).layout!;
          expect(
            layout,
            AppFrameLayout.resolve(
              width: size.width,
              scale: scale,
              panes: AppFramePanes.baseline,
            ),
          );
          // Chrome is bounded: the page keeps the rest of the window.
          final status = tester.getRect(find.byType(StatusBar));
          expect(status.bottom, lessThanOrEqualTo(size.height + 0.5));
          expectHittable(tester, toolbarKey('Save'));
          await showProperties(tester);

          // Date: the calendar by mouse.
          await click(tester, propertyValue('date'));
          await click(
            tester,
            find.descendant(
              of: propertyEditor('date'),
              matching: find.byKey(const ValueKey('era-date-drop')),
            ),
          );
          await click(tester, find.byKey(const ValueKey('era-day-2026-10-09')));
          await press(tester, LogicalKeyboardKey.enter);
          expect(showcase.events, contains('commit:d7:date'));
          // Type: the choice list by mouse (Enter opened it next).
          await click(tester, propertyEditor('type'));
          await click(tester, comboChoice('Night'));
          await press(tester, LogicalKeyboardKey.enter);
          expect(showcase.value('type'), 'night');
          // Start: a spin arrow.
          await click(
            tester,
            find.descendant(
              of: propertyEditor('start'),
              matching: find.byKey(const ValueKey('era-time-up')),
            ),
          );
          await press(tester, LogicalKeyboardKey.enter);
          expect(showcase.value('start'), const LocalTime(8, 0));
          await press(tester, LogicalKeyboardKey.escape);
          // A check box value.
          await click(tester, propertyValue('ok'));
          await click(
            tester,
            find.descendant(
              of: propertyEditor('ok'),
              matching: find.byKey(const ValueKey('era-check-box')),
            ),
          );
          await press(tester, LogicalKeyboardKey.escape);
          // A refused value shows its reason in the description.
          await click(tester, propertyValue('note'));
          await tester.enterText(propertyEditor('note'), '');
          await press(tester, LogicalKeyboardKey.enter);
          final reason = find.descendant(
            of: find.byKey(const ValueKey('property-description')),
            matching: find.textContaining('Enter a note'),
          );
          await tester.ensureVisible(reason);
          await tester.pumpAndSettle();
          expectHittable(tester, reason, alignment: Alignment.topLeft);
          // Undo throws the draft and the pending edit away; Save keeps.
          await click(tester, toolbarKey('Undo'));
          expect(showcase.controller.session, isNull);
          expect(showcase.events.last, 'undo');
          await click(tester, propertyValue('note'));
          await tester.enterText(propertyEditor('note'), 'Kept');
          await click(tester, toolbarKey('Save'));
          expect(showcase.events.last, 'save');
          expect(showcase.value('note'), 'Kept');

          // A grid cell editor and its error.
          await click(tester, await gridCell(tester, 'd7', 'end'));
          await click(
            tester,
            find.descendant(
              of: find.byKey(const ValueKey('grid-editor:end')),
              matching: find.byKey(const ValueKey('era-time-down')),
            ),
          );
          await press(tester, LogicalKeyboardKey.escape);

          // The action panel takes the property column or its tab.
          await click(tester, toolbarKey('Confirm worked days…'));
          expect(showcase.actionOpen, isTrue);
          await click(tester, find.byKey(const ValueKey('action-hours')));
          await tester.enterText(
            find.byKey(const ValueKey('action-hours')),
            'x',
          );
          await press(tester, LogicalKeyboardKey.enter);
          await tester.ensureVisible(find.text('Enter whole hours.'));
          await tester.pumpAndSettle();
          expectHittable(
            tester,
            find.text('Enter whole hours.'),
            alignment: Alignment.topLeft,
          );
          await press(tester, LogicalKeyboardKey.escape);
          await click(tester, pushKey('Cancel'));
          expect(showcase.events.last, 'cancel');
          await click(tester, toolbarKey('Confirm worked days…'));
          await click(tester, pushKey('Confirm 3 days'));
          expect(showcase.events.last, 'primary');
          expect(showcase.actionOpen, isFalse);

          if (layout.treeFolded) {
            await click(tester, treeKey);
            expectHittable(
              tester,
              find.descendant(of: treeOverlay, matching: find.text('Details')),
            );
            await click(tester, find.bySemanticsLabel('Close the tree'));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('long tabs and errors', () {
    for (final (size, scale) in const [
      (Size(800, 600), 2.0),
      (Size(1280, 800), 2.0),
      (Size(1024, 768), 1.0),
      (Size(860, 650), 1.0),
    ]) {
      testWidgets('${size.width.toInt()} x ${size.height.toInt()} at '
          '${scale * 100} %', (tester) async {
        final showcase = await pumpAppFrame(
          tester,
          size,
          scale: scale,
          knobs: const GalleryKnobs(error: true, longText: true),
        );
        await click(tester, find.text('Tracking of habits and measures'));
        expect(showcase.area, 'tracking');
        await click(tester, find.text('How the pay of this day is worked out'));
        expect(showcase.subformTab, 'working');
        await click(
          tester,
          find.text('Breaks taken during this shift (unpaid)'),
        );
        expect(showcase.subformTab, 'breaks');
        await showProperties(tester);
        await click(tester, propertyValue('end'));
        final error = find.descendant(
          of: find.byKey(const ValueKey('property-description')),
          matching: find.textContaining('Enter a valid value.'),
        );
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        expectHittable(tester, error, alignment: Alignment.topLeft);
        await press(tester, LogicalKeyboardKey.escape);
        await click(tester, toolbarKey('Confirm the worked days…'));
        await showProperties(tester, label: 'Confirm days');
        await click(tester, pushKey('Confirm 3 days'));
        expect(showcase.events.last, 'primary');
        if (frameOf(tester).layout!.treeFolded) {
          await click(tester, treeKey);
          await click(
            tester,
            find.descendant(
              of: treeOverlay,
              matching: find.text('3 days to confirm'),
            ),
          );
          expect(showcase.events.last, 'follow:confirm');
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('small and short windows', () {
    for (final size in const [
      Size(800, 600),
      Size(800, 420),
      Size(1280, 360),
    ]) {
      testWidgets('${size.width.toInt()} x ${size.height.toInt()} at 200 %: '
          'chrome scrolls in a bounded region, commands and footer reachable', (
        tester,
      ) async {
        final showcase = await pumpAppFrame(tester, size, scale: 2);
        final status = tester.getRect(find.byType(StatusBar));
        expect(status.bottom, lessThanOrEqualTo(size.height + 0.5));
        final page = tester.getRect(
          find.byKey(const ValueKey('app-frame-middle-column')),
        );
        expect(page.top, lessThanOrEqualTo(size.height * 0.7 + 0.5));
        await click(tester, toolbarKey('Save'));
        await click(tester, find.text('Knowledge'));
        expect(showcase.area, 'knowledge');
        await click(tester, toolbarKey('Confirm worked days…'));
        await showProperties(tester, label: 'Confirm days');
        await click(tester, pushKey('Cancel'));
        expect(showcase.events.last, 'cancel');
        // No text is shrunk to fit.
        final style = tester.widget<Text>(find.text('Knowledge')).style;
        expect(style?.fontSize, anyOf(isNull, 11));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
