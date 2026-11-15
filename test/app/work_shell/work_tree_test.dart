import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_tree.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/ui/ui.dart';

const _depot = EmploymentId('0190f5d2-6a00-7000-8000-000000000001');
const _cafe = EmploymentId('0190f5d2-6a00-7000-8000-000000000002');

const _counts = SheetCounts(
  shifts: 2,
  leave: 0,
  schedules: 1,
  periods: 0,
  payslips: 0,
  agreements: 1,
);

EmploymentSummary _summary(
  EmploymentId id,
  String name, {
  bool archived = false,
}) {
  final employment = Employment.create(
    id: id,
    name: name,
    legalLabel: null,
    nowUtc: DateTime.utc(2026, 10, 1),
  );
  return EmploymentSummary(
    archived
        ? employment.archive(nowUtc: DateTime.utc(2026, 10, 2))
        : employment,
    counts: _counts,
    hasHistory: false,
  );
}

TreeNodeData _node(List<TreeNodeData> nodes, String id) {
  for (final node in nodes) {
    if (node.id == id) return node;
    final found = _find(node.children, id);
    if (found != null) return found;
  }
  throw StateError('no node $id');
}

TreeNodeData? _find(List<TreeNodeData> nodes, String id) {
  for (final node in nodes) {
    if (node.id == id) return node;
    final found = _find(node.children, id);
    if (found != null) return found;
  }
  return null;
}

void main() {
  final depot = 'employment:${_depot.value}';

  test('an employment lists its sheets with their counts', () {
    final nodes = workTreeNodes(
      employments: [_summary(_depot, 'Synthetic depot')],
      pastDays: const {},
      place: WorkLocation.employment(_depot),
    );
    final labels = [
      for (final node in _node(nodes, depot).children) node.label,
    ];
    expect(labels, [
      'Calendar',
      'Shifts',
      'Leave',
      'Schedules',
      'Pay periods',
      'Payslips',
      'Agreements',
      'To confirm',
    ]);
    int? count(String label) => _node(
      nodes,
      depot,
    ).children.singleWhere((node) => node.label == label).count;
    expect(count('Shifts'), 2);
    expect(count('Schedules'), 1);
    expect(count('Agreements'), 1);
    expect(count('Leave'), 0);
    expect(_node(nodes, 'work').count, 1);
  });

  test('every sheet node of an active employment is live', () {
    final nodes = workTreeNodes(
      employments: [_summary(_depot, 'Synthetic depot')],
      pastDays: const {},
      place: WorkLocation.employment(_depot),
    );
    final sheets = _node(nodes, depot).children;
    expect(sheets, hasLength(8));
    for (final node in sheets) {
      expect(node.muted, isFalse, reason: node.label);
      expect(node.id, endsWith(':${_depot.value}'), reason: node.label);
      expect(node.id, isNot(startsWith('later:')), reason: node.label);
    }
  });

  test('To confirm is a warning only while days wait', () {
    TreeNodeData toConfirm(int days) => _node(
      workTreeNodes(
        employments: [_summary(_depot, 'Synthetic depot')],
        pastDays: {_depot: (toConfirm: days, withoutAgreement: 3)},
        place: const WorkLocation.overview(),
      ),
      'toConfirm:${_depot.value}',
    );
    expect(toConfirm(9).count, 9);
    expect(toConfirm(9).warning, isTrue);
    expect(toConfirm(0).count, 0);
    expect(toConfirm(0).warning, isFalse);
  });

  test('archived employments sit in Ended employments', () {
    final nodes = workTreeNodes(
      employments: [
        _summary(_depot, 'Synthetic depot'),
        _summary(_cafe, 'Synthetic cafe', archived: true),
      ],
      pastDays: const {},
      place: const WorkLocation.overview(),
    );
    final root = _node(nodes, 'work');
    expect([for (final node in root.children) node.id], [depot, 'ended']);
    final ended = _node(nodes, 'ended');
    expect(ended.count, 1);
    expect(ended.muted, isTrue);
    expect(ended.expanded, isFalse);
    expect(ended.children.single.id, 'employment:${_cafe.value}');
  });

  test('counts are left out while the employments cannot be read', () {
    final nodes = workTreeNodes(
      employments: [_summary(_depot, 'Synthetic depot')],
      pastDays: const {},
      place: const WorkLocation.overview(),
      countsKnown: false,
    );
    expect(
      _node(nodes, depot).children.map((node) => node.count),
      everyElement(isNull),
    );
  });

  test('Agreements is a live node with its count', () {
    final nodes = workTreeNodes(
      employments: [_summary(_depot, 'Synthetic depot')],
      pastDays: const {},
      place: const WorkLocation.agreements(_depot),
    );
    final agreements = _node(nodes, 'agreements:${_depot.value}');
    expect(agreements.muted, isFalse);
    expect(agreements.count, 1);
    expect(_node(nodes, 'leave:${_depot.value}').muted, isFalse);
    expect(
      treeIdOf(const WorkLocation.agreements(_depot)),
      'agreements:${_depot.value}',
    );
  });

  test('an employment without past-day counts shows no To confirm count', () {
    final nodes = workTreeNodes(
      employments: [_summary(_depot, 'Synthetic depot', archived: true)],
      pastDays: const {},
      place: const WorkLocation.overview(),
    );
    final waiting = _node(nodes, 'toConfirm:${_depot.value}');
    expect(waiting.count, isNull);
    expect(waiting.warning, isFalse);
  });

  test('Schedules is a live node with its count', () {
    final nodes = workTreeNodes(
      employments: [_summary(_depot, 'Synthetic depot')],
      pastDays: const {},
      place: const WorkLocation.schedules(_depot),
    );
    final schedules = _node(nodes, 'schedules:${_depot.value}');
    expect(schedules.muted, isFalse);
    expect(schedules.count, 1);
    expect(schedules.icon, EraIconKind.schedule);
    expect(
      treeIdOf(const WorkLocation.schedules(_depot)),
      'schedules:${_depot.value}',
    );
  });
}
