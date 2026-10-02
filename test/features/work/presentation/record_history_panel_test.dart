import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/history/record_events.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/record_history_panel.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  const shift = WorkRecordRef(
    kind: WorkRecordKind.shift,
    id: ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
  );

  Future<void> pump(WidgetTester tester, List<RecordEvent> events) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            recordHistoryProvider.overrideWithValue(_History(events)),
          ],
          child: MaterialApp(
            theme: buildLifeOSTheme(highContrast: false),
            home: LifeOSSkinScope(
              child: Scaffold(
                body: RecordTabs(
                  record: shift,
                  details: const Text('Synthetic details'),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('details show first; History lists events newest first', (
    tester,
  ) async {
    await pump(tester, [
      _event(1, RecordEventKind.created, const [
        FieldChange('State', null, 'running'),
      ]),
      _event(2, RecordEventKind.voided, const [
        FieldChange('State', 'finalized', 'voided'),
      ], reason: 'Synthetic end time'),
    ]);
    expect(find.text('Synthetic details'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Synthetic details'), findsNothing);
    expect(find.text('Voided'), findsOneWidget);
    expect(find.text('Reason: Synthetic end time'), findsOneWidget);
    expect(find.text('State: finalized → voided'), findsOneWidget);
    expect(find.text('State: running'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Voided')).dy,
      lessThan(tester.getTopLeft(find.text('Created')).dy),
    );
  });

  testWidgets('a record without events says so', (tester) async {
    await pump(tester, const []);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No history yet.'), findsOneWidget);
  });
}

RecordEvent _event(
  int id,
  RecordEventKind kind,
  List<FieldChange> changes, {
  String? reason,
}) => RecordEvent(
  id: id,
  recordKind: 'shift',
  recordId: '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31',
  atUtc: DateTime.utc(2026, 9, 10, 6 + id),
  kind: kind,
  changes: changes,
  reason: reason,
  revisionAfter: id,
);

final class _History implements RecordHistory {
  const _History(this.events);

  final List<RecordEvent> events;

  @override
  Stream<List<RecordEvent>> watch(String recordKind, String recordId) =>
      Stream.value(events);
}
