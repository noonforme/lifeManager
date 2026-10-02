/// Desk layouts (shell spec 6.4); each holds a fixed number of tiles.
enum DeskLayout {
  single(1),
  twoColumns(2),
  mainAndSide(4);

  const DeskLayout(this.capacity);

  /// The most tiles the layout shows.
  final int capacity;
}

/// The starter desks every install begins with.
enum StarterDesk { today, weeklyReview, monthClose }

final class DeskTile {
  const DeskTile({
    required this.id,
    required this.position,
    required this.sheetRef,
    this.viewId,
  });

  final String id;
  final int position;
  final String sheetRef;
  final String? viewId;
}

final class Desk {
  const Desk({
    required this.id,
    required this.name,
    required this.starter,
    required this.layout,
    required this.position,
    required this.revision,
    required this.tiles,
  });

  final String id;
  final String name;
  final StarterDesk? starter;
  final DeskLayout layout;
  final int position;
  final int revision;
  final List<DeskTile> tiles;

  /// Today stays; every other desk can be deleted.
  bool get canDelete => starter != StarterDesk.today;
}

/// Sheet keys a tile can show in Phase 1.
abstract final class DeskSheets {
  static const journalRecent = 'journal.recent';
  static const needsYou = 'work.needsYou';
  static const workThisPeriod = 'work.thisPeriod';
  static const shiftsThisWeek = 'work.shifts.week';
  static const payPeriods = 'work.periods';
  static const monthPeriods = 'work.periods.month';
  static const monthChecklist = 'work.monthChecklist';

  static const all = [
    journalRecent,
    needsYou,
    workThisPeriod,
    shiftsThisWeek,
    payPeriods,
    monthPeriods,
    monthChecklist,
  ];
}

/// What a starter desk holds when created or reset (shell spec 6.4).
({String name, DeskLayout layout, List<String> sheets}) starterDesk(
  StarterDesk starter,
) => switch (starter) {
  StarterDesk.today => (
    name: 'Today',
    layout: DeskLayout.mainAndSide,
    sheets: const [
      DeskSheets.journalRecent,
      DeskSheets.needsYou,
      DeskSheets.workThisPeriod,
    ],
  ),
  StarterDesk.weeklyReview => (
    name: 'Weekly review',
    layout: DeskLayout.twoColumns,
    sheets: const [DeskSheets.shiftsThisWeek, DeskSheets.payPeriods],
  ),
  StarterDesk.monthClose => (
    name: 'Month close',
    layout: DeskLayout.mainAndSide,
    sheets: const [DeskSheets.monthPeriods, DeskSheets.monthChecklist],
  ),
};
