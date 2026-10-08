import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/date_trace.dart';
import 'package:lifeos/shared/workbench/era_date_field.dart';
import 'package:lifeos/shared/workbench/era_dates.dart';
import 'package:lifeos/shared/workbench/era_month_calendar.dart';

import '../support/scheduled_app.dart';
import '../support/work_sheets.dart';

/// The owner finds the date boxes broken with a real mouse (bead
/// lifeManager-7qj), where touch taps never showed it. Each host's box is
/// driven here as a desktop mouse drives it, on Linux: hovering on its way,
/// holding each button about 100 ms, with 16 ms frames between events.

final class _Mouse {
  _Mouse(this.tester, this.gesture, this.at);

  static _Mouse? _plugged;

  final WidgetTester tester;
  final TestGesture gesture;
  Offset at;

  static Future<_Mouse> plug(WidgetTester tester) async {
    const start = Offset(2, 2);
    // One mouse a test: a second would be plugged into the same port.
    if (_plugged case final mouse? when mouse.tester == tester) return mouse;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: start);
    addTearDown(() {
      _plugged = null;
      return gesture.removePointer();
    });
    await tester.pump(const Duration(milliseconds: 16));
    return _plugged = _Mouse(tester, gesture, start);
  }

  Future<void> frames(int milliseconds) async {
    for (var left = milliseconds; left > 0; left -= 16) {
      await tester.pump(Duration(milliseconds: left < 16 ? left : 16));
    }
  }

  /// Glides to [to] in six hover steps, one a frame.
  Future<void> moveTo(Offset to) async {
    final from = at;
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(Offset.lerp(from, to, step / 6)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    at = to;
  }

  /// Presses at [where] for [hold] ms, slipping [slip] while held as a
  /// hand does, and waits [after] ms.
  Future<void> click(
    Offset where, {
    int hold = 96,
    int after = 200,
    Offset slip = Offset.zero,
  }) async {
    if (where != at) await moveTo(where);
    await gesture.down(where);
    await frames(hold ~/ 2);
    if (slip != Offset.zero) {
      await gesture.moveTo(where + slip);
      at = where + slip;
    }
    await frames(hold - hold ~/ 2);
    await gesture.up();
    await frames(after);
  }

  /// One notch of the wheel at [where].
  Future<void> wheel(Offset where) async {
    await moveTo(where);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: where,
        scrollDelta: const Offset(0, 40),
      ),
    );
    await frames(100);
  }
}

final _previous = find.byKey(const ValueKey('era-calendar-previous'));
final _next = find.byKey(const ValueKey('era-calendar-next'));
final _today = find.byKey(const ValueKey('era-calendar-today'));
final _calendar = find.byType(EraMonthCalendar);

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('era-calendar-title'))).data!;

LocalDate _shownMonth(WidgetTester tester) {
  final [name, year] = _title(tester).split(' ');
  return LocalDate(int.parse(year), eraMonthNames.indexOf(name) + 1, 1);
}

Finder _field(String key) => find.ancestor(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(EraDateField),
);

LocalDate? _value(WidgetTester tester, String key) =>
    tester.widget<EraDateField>(_field(key)).value;

Offset _arrow(WidgetTester tester, String key) => tester.getCenter(
  find.descendant(
    of: _field(key),
    matching: find.byKey(const ValueKey('era-date-drop')),
  ),
);

/// Where the box keyed [key] draws its text from [start] to [end]: in "Mon
/// 2026-10-05" the weekday is 0–3 and the month 9–11.
Offset _text(WidgetTester tester, String key, int start, int end) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(RichText),
    ),
  );
  final box = paragraph
      .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))
      .first;
  return paragraph.localToGlobal(box.toRect().center);
}

Future<_Mouse> _reach(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  final mouse = await _Mouse.plug(tester);
  // Wander over the form first, as a hand does.
  await mouse.moveTo(
    tester.getTopLeft(find.byKey(ValueKey(key))) - const Offset(40, 30),
  );
  return mouse;
}

/// Opens with the arrow, pages ▸ three times past ◂ and Today, double
/// clicks ▸, and picks the 12th with a slipping hand: one month per click,
/// the calendar open throughout, the 12th picked.
Future<void> _page(WidgetTester tester, String key) async {
  final mouse = await _reach(tester, key);
  await mouse.click(_arrow(tester, key));
  expect(_calendar, findsOneWidget, reason: 'the arrow opens');
  var month = _shownMonth(tester);
  for (var click = 0; click < 3; click++) {
    await mouse.moveTo(tester.getCenter(_previous));
    await mouse.moveTo(tester.getCenter(_today));
    await mouse.click(tester.getCenter(_next), slip: const Offset(2, 1));
    month = month.addMonths(1);
    expect(_calendar, findsOneWidget, reason: 'open after ▸ $click');
    expect(_title(tester), eraMonthTitle(month), reason: '▸ $click');
  }
  await mouse.click(tester.getCenter(_next), hold: 64, after: 64);
  await mouse.click(tester.getCenter(_next), hold: 64);
  month = month.addMonths(2);
  expect(_calendar, findsOneWidget, reason: 'open after a double click');
  expect(_title(tester), eraMonthTitle(month), reason: 'a double click');
  final day = LocalDate(month.year, month.month, 12);
  await mouse.click(
    tester.getCenter(find.byKey(ValueKey('era-day-$day'))),
    slip: const Offset(-1, 2),
  );
  await tester.pumpAndSettle();
  expect(_calendar, findsNothing, reason: 'a pick closes');
  expect(_value(tester, key), day);
}

/// The weekday opens; the wheel over the open calendar leaves it be; the
/// weekday again closes it for good; the digits select without opening; a
/// double click on the arrow opens and closes; the wheel over the form
/// behind closes it. The date never changes.
Future<void> _closedBox(WidgetTester tester, String key) async {
  final before = _value(tester, key);
  final mouse = await _reach(tester, key);
  final weekday = _text(tester, key, 0, 3);
  await mouse.click(weekday);
  expect(_calendar, findsOneWidget, reason: 'the weekday opens');
  final title = _title(tester);
  await mouse.wheel(tester.getCenter(_calendar));
  expect(_calendar, findsOneWidget, reason: 'the wheel over it');
  expect(_title(tester), title);
  await mouse.click(weekday);
  await tester.pumpAndSettle();
  expect(_calendar, findsNothing, reason: 'the weekday closes');
  await mouse.click(_text(tester, key, 9, 11));
  await tester.pumpAndSettle();
  expect(_calendar, findsNothing, reason: 'the digits select');
  await mouse.click(_arrow(tester, key), hold: 64, after: 64);
  await mouse.click(_arrow(tester, key), hold: 64);
  await tester.pumpAndSettle();
  expect(_calendar, findsNothing, reason: 'a double click opens and closes');
  await mouse.click(_arrow(tester, key));
  expect(_calendar, findsOneWidget, reason: 'the arrow opens');
  await mouse.wheel(
    tester.getTopLeft(find.byKey(ValueKey(key))) - const Offset(30, 10),
  );
  await tester.pumpAndSettle();
  expect(_value(tester, key), before);
}

typedef _Host = ({String key, Future<void> Function(WidgetTester) open});

final _hosts = <String, _Host>{
  'Work › Date range… From': (
    key: 'range-from',
    open: (tester) async {
      await pumpScheduledApp(
        tester,
        location: '/work?employment={employment}&sheet=shifts',
      );
      await tester.tap(find.bySemanticsLabel(RegExp('^Period, ')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date range…'));
      await tester.pumpAndSettle();
    },
  ),
  'the manual shift start date': (
    key: 'shift-start-date',
    open: (tester) async {
      await pumpScheduledApp(
        tester,
        location: '/work?employment={employment}&sheet=shifts',
      );
      await tester.tap(find.byKey(const ValueKey('quick-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manual shift').last);
      await tester.pumpAndSettle();
    },
  ),
  'a schedule\'s Properties In use from': (
    key: 'schedule-from',
    open: (tester) => pumpScheduledApp(
      tester,
      location:
          '/work?employment={employment}&sheet=schedules'
          '&record=schedule:{schedule}&mode=properties',
    ),
  ),
  'a new schedule\'s In use from': (
    key: 'schedule-from',
    open: (tester) async {
      await pumpScheduledApp(tester);
      await tester.tap(find.widgetWithText(TaskLink, 'New schedule…'));
      await tester.pumpAndSettle();
    },
  ),
  'an agreement\'s Properties Starts on': (
    key: 'agreement-effective-start',
    open: (tester) async {
      await pumpScheduledApp(tester);
      await chooseSheet(tester, 'Agreements');
      await tester.tap(find.text('v1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Properties').first);
      await tester.pumpAndSettle();
    },
  ),
  '+ Add › Extra shift… date': (
    key: 'add-day-date',
    open: (tester) async {
      await pumpScheduledApp(tester);
      await tester.tap(find.byKey(const ValueKey('quick-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extra shift…').last);
      await tester.pumpAndSettle();
    },
  ),
};

/// The window at [ratio] device pixels per logical pixel, [logical] big.
Future<void> _window(WidgetTester tester, double ratio, Size logical) async {
  tester.view.devicePixelRatio = ratio;
  tester.view.physicalSize = logical * ratio;
  await tester.pumpAndSettle();
}

void _linux(String description, WidgetTesterCallback body) => testWidgets(
  description,
  body,
  variant: TargetPlatformVariant.only(TargetPlatform.linux),
);

void main() {
  for (final MapEntry(key: name, value: host) in _hosts.entries) {
    _linux('$name: a mouse pages and picks', (tester) async {
      await host.open(tester);
      await _page(tester, host.key);
    });

    _linux('$name: a mouse on the closed box', (tester) async {
      await host.open(tester);
      await _closedBox(tester, host.key);
    });
  }

  for (final name in [
    'Work › Date range… From',
    'an agreement\'s Properties Starts on',
  ]) {
    final host = _hosts[name]!;
    for (final ratio in [1.25, 1.5]) {
      _linux('$name at ${ratio}x in a 1920 × 1080 window', (tester) async {
        await host.open(tester);
        await _window(tester, ratio, const Size(1920, 1080));
        await _page(tester, host.key);
        await _closedBox(tester, host.key);
      });
    }
  }

  _linux('the date trace changes nothing a mouse does', (tester) async {
    final home = Directory.systemTemp.createTempSync('lifeos-trace-');
    dateTrace = DateTrace(File('${home.path}/date-trace.log'));
    addTearDown(() {
      dateTrace?.close();
      dateTrace = null;
      home.deleteSync(recursive: true);
    });
    final host = _hosts['an agreement\'s Properties Starts on']!;
    await host.open(tester);
    await _page(tester, host.key);
    await _closedBox(tester, host.key);
    expect(
      File('${home.path}/date-trace.log').readAsStringSync(),
      contains('[Starts on] cursor'),
    );
  });
}
