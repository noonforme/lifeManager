import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/features/work/data/daos/shift_dao.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/work_register.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  testWidgets('empty register gives a first-run employment action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestWorkRegister(
        projection: WorkRegisterProjection.empty(
          const WorkScope(employmentId: null, temporal: null),
        ),
      ),
    );

    expect(find.text('Create an employment to begin.'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Create employment'),
      findsOneWidget,
    );
  });

  testWidgets('unavailable projection is explicit and recoverable', (
    tester,
  ) async {
    await tester.pumpWidget(const _TestWorkRegister(projection: null));

    expect(find.text('Work records unavailable'), findsOneWidget);
    expect(
      find.text('Reload Work to inspect the current records.'),
      findsOneWidget,
    );
  });

  testWidgets('single click selects a typed shift record', (tester) async {
    final selected = <WorkRecordRef>[];
    await tester.pumpWidget(
      _TestWorkRegister(projection: _projection(), onSelect: selected.add),
    );

    await tester.tap(find.bySemanticsLabel('Shift on 2026-09-29'));

    expect(selected, hasLength(1));
    expect(selected.single.kind, WorkRecordKind.shift);
    expect(selected.single.id, _shiftId);
  });

  testWidgets(
    'summary amounts use tabular figures and label expected as estimate',
    (tester) async {
      await tester.pumpWidget(_TestWorkRegister(projection: _projection()));

      expect(find.text('Expected estimate'), findsOneWidget);
      final paid = tester.widget<Text>(find.text('EUR 123.45'));
      expect(
        paid.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    },
  );

  testWidgets('two-times text scale keeps all toolbar controls reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 760);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _TestWorkRegister(projection: _projection(), textScale: 2),
    );

    for (final label in ['Employment', 'Scope', 'Status']) {
      final control = find.widgetWithText(OutlinedButton, label);
      expect(control, findsOneWidget);
      await tester.ensureVisible(control);
    }
    final primaryAction = find.widgetWithText(FilledButton, 'Add shift');
    expect(primaryAction, findsOneWidget);
    await tester.ensureVisible(primaryAction);
    expect(tester.takeException(), isNull);
  });
}

final class _TestWorkRegister extends StatelessWidget {
  const _TestWorkRegister({
    required this.projection,
    this.onSelect,
    this.textScale = 1,
  });

  final WorkRegisterProjection? projection;
  final ValueChanged<WorkRecordRef>? onSelect;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLifeOSTheme(highContrast: false),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: WorkRegister(
            projection: projection,
            selectedRecord: null,
            onSelect: onSelect ?? (_) {},
            onPrimaryAction: () {},
          ),
        ),
      ),
    );
  }
}

WorkRegisterProjection _projection() => WorkRegisterProjection(
  scope: const WorkScope(employmentId: _employmentId, temporal: null),
  period: null,
  shiftRows: [
    ShiftRegisterRow(
      id: _shiftId,
      localStartDate: '2026-09-29',
      startUtc: DateTime.utc(2026, 9, 29, 8),
      endUtc: DateTime.utc(2026, 9, 29, 16),
      state: ShiftState.finalized,
    ),
  ],
  payslipRows: const [],
  paid: const Money(minorUnits: 12345),
  reconciliation: null,
);

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _shiftId = ShiftId('00000000-0000-7000-8000-000000000001');
