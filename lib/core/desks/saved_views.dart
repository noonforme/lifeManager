import 'dart:convert';

import '../outcomes/mutation_outcome.dart';
import '../time/local_date.dart';

/// The kinds of value a view filter may hold. Each is structural (an id, a
/// date or a flag), so a view can never store personal text.
enum ViewValue { id, date, flag }

/// The sheets a view can be saved from, with the filters and columns each
/// accepts (shell spec 6.9).
abstract final class ViewSheets {
  static const workShifts = 'work.shifts';
  static const workPeriods = 'work.periods';
  static const workPayslips = 'work.payslips';
  static const workAgreements = 'work.agreements';

  static const _workFilters = {
    'employment': ViewValue.id,
    'period': ViewValue.id,
    'from': ViewValue.date,
    'to': ViewValue.date,
    'void': ViewValue.flag,
  };

  static const shapes =
      <String, ({Map<String, ViewValue> filters, List<String> columns})>{
        workShifts: (
          filters: _workFilters,
          columns: [
            'date',
            'start',
            'end',
            'break',
            'paid',
            'night',
            'holiday',
            'overtime',
            'pay',
            'state',
          ],
        ),
        workPeriods: (
          filters: _workFilters,
          columns: [
            'start',
            'end',
            'shifts',
            'expected',
            'paid',
            'difference',
            'state',
          ],
        ),
        workPayslips: (
          filters: _workFilters,
          columns: [
            'issued',
            'paidOn',
            'period',
            'basis',
            'amount',
            'reference',
            'state',
          ],
        ),
        workAgreements: (
          filters: _workFilters,
          columns: [
            'version',
            'from',
            'to',
            'rate',
            'basis',
            'overtime',
            'night',
            'holiday',
            'stacking',
            'inUse',
          ],
        ),
      };
}

/// A sort on one column.
final class ViewSort {
  const ViewSort(this.column, {this.descending = false});

  final String column;
  final bool descending;

  @override
  bool operator ==(Object other) =>
      other is ViewSort &&
      other.column == column &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(column, descending);
}

/// What a view shows: a sheet with its filters, sort and visible columns.
/// A null sort or column list keeps the sheet's own.
final class ViewShape {
  const ViewShape({
    required this.sheetRef,
    this.filters = const {},
    this.sort,
    this.columns,
  });

  final String sheetRef;
  final Map<String, String> filters;
  final ViewSort? sort;
  final List<String>? columns;

  String get filtersJson => jsonEncode(
    Map.fromEntries(
      filters.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
  );

  String? get sortJson => switch (sort) {
    null => null,
    final sort => jsonEncode({
      'column': sort.column,
      'descending': sort.descending,
    }),
  };

  String? get columnsJson => columns == null ? null : jsonEncode(columns);

  /// Reads a stored shape; anything that does not validate is null.
  static ViewShape? decode({
    required String sheetRef,
    required String filtersJson,
    required String? sortJson,
    required String? columnsJson,
  }) {
    try {
      final filters = (jsonDecode(filtersJson) as Map<String, Object?>).map(
        (key, value) => MapEntry(key, value! as String),
      );
      final sort = sortJson == null
          ? null
          : jsonDecode(sortJson) as Map<String, Object?>;
      final shape = ViewShape(
        sheetRef: sheetRef,
        filters: filters,
        sort: sort == null
            ? null
            : ViewSort(
                sort['column']! as String,
                descending: sort['descending']! as bool,
              ),
        columns: columnsJson == null
            ? null
            : [
                for (final column in jsonDecode(columnsJson) as List)
                  column as String,
              ],
      );
      return viewShapeIssues(shape).isEmpty ? shape : null;
    } on Object {
      return null;
    }
  }
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Why [shape] cannot be saved, by field; empty when it can.
Map<String, List<FieldIssue>> viewShapeIssues(ViewShape shape) {
  final definition = ViewSheets.shapes[shape.sheetRef];
  if (definition == null) {
    return const {
      'sheetRef': [FieldIssue(FieldIssueCode.invalid)],
    };
  }
  bool valid(ViewValue kind, String value) => switch (kind) {
    ViewValue.id => _uuid.hasMatch(value),
    ViewValue.date => LocalDate.tryParse(value)?.toString() == value,
    ViewValue.flag => value == '1',
  };
  final issues = <String, List<FieldIssue>>{};
  for (final MapEntry(:key, :value) in shape.filters.entries) {
    final kind = definition.filters[key];
    if (kind == null || !valid(kind, value)) {
      issues['filters.$key'] = const [FieldIssue(FieldIssueCode.invalid)];
    }
  }
  final from = shape.filters['from'];
  final to = shape.filters['to'];
  if ((from == null) != (to == null) ||
      (shape.filters.containsKey('period') && from != null) ||
      (from != null && to != null && to.compareTo(from) < 0)) {
    issues['filters'] = const [FieldIssue(FieldIssueCode.invalid)];
  }
  if (shape.sort case final sort?
      when !definition.columns.contains(sort.column)) {
    issues['sort'] = const [FieldIssue(FieldIssueCode.invalid)];
  }
  if (shape.columns case final columns?
      when columns.isEmpty ||
          columns.toSet().length != columns.length ||
          columns.any((column) => !definition.columns.contains(column))) {
    issues['columns'] = const [FieldIssue(FieldIssueCode.invalid)];
  }
  return issues;
}

/// A named, saved view.
final class SavedView {
  const SavedView({
    required this.id,
    required this.name,
    required this.shape,
    required this.position,
    required this.revision,
  });

  final String id;
  final String name;
  final ViewShape shape;
  final int position;
  final int revision;
}
