import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart'
    show EmploymentsWords;
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_menus.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/ui/ui.dart';

const _depot = EmploymentId('0190f5d2-6a00-7000-8000-000000000001');

void main() {
  List<AppMenu> menus({
    WorkLocation place = const WorkLocation.overview(),
    VoidCallback? onTree,
  }) => workMenus(
    place: place,
    onNewEmployment: () {},
    onQuit: () {},
    edit: const [],
    onBack: null,
    onForward: null,
    onSheet: (_) {},
    record: const [],
    onTree: onTree,
    onRestorePanes: () {},
    onLicences: () {},
  );

  List<EraMenuItem> menu(List<AppMenu> menus, String label) =>
      menus.singleWhere((menu) => menu.label == label).items;

  EraMenuItem item(List<EraMenuItem> items, String label) =>
      items.singleWhere((item) => item.label == label);

  test("the menu bar has the era's seven menus in order", () {
    expect(
      [for (final menu in menus()) menu.label],
      ['File', 'Edit', 'View', 'Record', 'Tools', 'Window', 'Help'],
    );
  });

  test('View lists the employment\'s sheets, greyed only without one', () {
    final view = menu(
      menus(
        place: WorkLocation.shifts(_depot, month: const LocalDate(2026, 10, 1)),
      ),
      'View',
    );
    expect(item(view, 'Shifts').onSelected, isNotNull);
    expect(item(view, 'Calendar').onSelected, isNotNull);
    expect(item(view, 'To confirm').onSelected, isNotNull);
    expect(item(view, 'Leave').onSelected, isNotNull);
    expect(item(view, 'Leave').disabledReason, isNull);
    final overview = menu(menus(), 'View');
    expect(item(overview, 'Shifts').onSelected, isNull);
    expect(
      item(overview, 'Shifts').disabledReason,
      WorkMenuWords.selectEmployment,
    );
  });

  test('Tools offers nothing yet, and says so', () {
    final options = item(menu(menus(), 'Tools'), 'Options…');
    expect(options.onSelected, isNull);
    expect(options.disabledReason, WorkMenuWords.noOptions);
  });

  test('Window opens the tree only while it is folded', () {
    expect(item(menu(menus(), 'Window'), 'Tree').onSelected, isNull);
    expect(
      item(menu(menus(onTree: () {}), 'Window'), 'Tree').onSelected,
      isNotNull,
    );
  });

  test('Add offers Employment… everywhere and Manual shift on Shifts', () {
    expect(
      [for (final item in workAddItems(onEmployment: () {})) item.label],
      ['Employment…'],
    );
    expect(
      [
        for (final item in workAddItems(
          onEmployment: () {},
          onManualShift: () {},
        ))
          item.label,
      ],
      ['Employment…', 'Manual shift'],
    );
    final greyed = workAddItems(
      onEmployment: () {},
      manualShiftBlocked: EmploymentsWords.archivedReadOnly,
    ).singleWhere((item) => item.label == 'Manual shift');
    expect(greyed.onSelected, isNull);
    expect(greyed.disabledReason, EmploymentsWords.archivedReadOnly);
  });

  test('View opens Agreements', () {
    final view = menu(
      menus(place: const WorkLocation.agreements(_depot)),
      'View',
    );
    expect(item(view, 'Agreements').onSelected, isNotNull);
    expect(item(view, 'Agreements').checked, isTrue);
    expect(item(view, 'Shifts').onSelected, isNotNull);
    expect(item(view, 'Shifts').checked, isFalse);
  });

  test('View opens Schedules', () {
    final view = menu(
      menus(place: const WorkLocation.schedules(_depot)),
      'View',
    );
    expect(item(view, 'Schedules').onSelected, isNotNull);
    expect(item(view, 'Schedules').checked, isTrue);
  });
}
