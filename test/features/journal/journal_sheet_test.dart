import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/journal/journal_controller.dart';
import 'package:lifeos/features/journal/journal_projection.dart';
import 'package:lifeos/features/journal/journal_sheet.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';

void main() {
  const range = JournalRange(
    from: LocalDate(2026, 9, 8),
    to: LocalDate(2026, 9, 14),
  );

  Future<(List<JournalRange>, List<JournalEntry>)> pump(
    WidgetTester tester,
    List<JournalEntry>? entries,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.reset);
    final ranges = <JournalRange>[];
    final opened = <JournalEntry>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(highContrast: false),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: JournalSheet(
              range: range,
              entries: entries,
              timezones: IanaTimezoneService(),
              onRange: ranges.add,
              onOpen: opened.add,
            ),
          ),
        ),
      ),
    );
    return (ranges, opened);
  }

  testWidgets('days group their entries under a summary', (tester) async {
    final (_, opened) = await pump(tester, [
      _entry(3, JournalKind.payslipRecorded, payslip: true, amount: 12345),
      _entry(2, JournalKind.shiftFinalized, amount: 16000, paid: 8 * 3600),
      _entry(1, JournalKind.shiftStarted),
    ]);

    expect(find.text('2026-09-10'), findsOneWidget);
    expect(
      find.text('paid 8:00 · expected EUR 160.00 · paid in EUR 123.45'),
      findsOneWidget,
    );
    expect(find.text('Shift finalized · Shift on 2026-09-10'), findsOneWidget);
    // 08:01 UTC is 11:01 in Vilnius.
    expect(find.text('11:01'), findsOneWidget);

    await tester.tap(find.text('Shift started · Shift on 2026-09-10'));
    expect(opened.single.kind, JournalKind.shiftStarted);
  });

  testWidgets('‹ and › move the range by its length', (tester) async {
    final (ranges, _) = await pump(tester, const []);
    expect(find.text('Nothing recorded on these days'), findsOneWidget);

    await tester.tap(find.text('‹'));
    await tester.tap(find.text('›'));
    expect(ranges[0].from, const LocalDate(2026, 9, 1));
    expect(ranges[0].to, const LocalDate(2026, 9, 7));
    expect(ranges[1].from, const LocalDate(2026, 9, 15));
  });

  test('a Journal route carries only its dates', () {
    expect(range.uri.toString(), '/journal?from=2026-09-08&to=2026-09-14');
    expect(JournalRange.fromUri(range.uri), range);
    expect(JournalRange.fromUri(Uri.parse('/journal?from=2026-09-08')), isNull);
  });
}

JournalEntry _entry(
  int sequence,
  JournalKind kind, {
  bool payslip = false,
  int? amount,
  int? paid,
}) => JournalEntry(
  atUtc: DateTime.utc(2026, 9, 10, 8).add(Duration(minutes: sequence)),
  localDate: const LocalDate(2026, 9, 10),
  area: LifeOSArea.work,
  kind: kind,
  record: WorkRecordRef(
    kind: payslip ? WorkRecordKind.payslip : WorkRecordKind.shift,
    id: payslip
        ? const PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61')
        : const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
  ),
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  zoneId: 'Europe/Vilnius',
  summary: payslip ? 'Payslip issued 2026-09-10' : 'Shift on 2026-09-10',
  state: payslip ? 'Effective' : 'Finalized',
  amount: amount == null ? null : Money(minorUnits: amount),
  paidSeconds: paid,
  sequence: sequence,
);
