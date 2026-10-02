import 'package:drift/drift.dart';

/// Owner preferences. Keys are fixed and values are structural tokens, so
/// nothing personal is stored here.
@DataClassName('PreferenceRow')
class Preferences extends Table {
  TextColumn get key =>
      text().check(const CustomExpression<bool>("key IN ('appearance')"))();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
