import 'package:drift/drift.dart';

/// Desks are structural only: names, layouts and which sheets they show.
@DataClassName('DeskRow')
class Desks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get starterKey => text().nullable().check(
    const CustomExpression<bool>(
      'starter_key IS NULL OR starter_key IN '
      "('today', 'weeklyReview', 'monthClose')",
    ),
  )();
  TextColumn get layout => text().check(
    const CustomExpression<bool>(
      "layout IN ('single', 'twoColumns', 'mainAndSide')",
    ),
  )();
  IntColumn get position => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (starter_key)'];
}

@DataClassName('DeskTileRow')
class DeskTiles extends Table {
  TextColumn get id => text()();
  TextColumn get deskId =>
      text().references(Desks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  /// A stable sheet key such as `work.shifts.week`.
  TextColumn get sheetRef => text()();
  TextColumn get viewId => text().nullable().references(
    SavedViews,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Saved views are structural only: a sheet key with ids, dates and flags
/// as filters, never record content.
@DataClassName('SavedViewRow')
class SavedViews extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sheetRef => text()();
  TextColumn get filtersJson => text()();
  TextColumn get sortJson => text().nullable()();
  TextColumn get columnsJson => text().nullable()();
  IntColumn get position => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
