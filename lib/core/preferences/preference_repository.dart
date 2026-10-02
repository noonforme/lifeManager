import '../database/app_database.dart';

/// The preferences LifeOS keeps.
enum PreferenceKey { appearance }

/// Reads and writes preferences. A value is one of the tokens its key
/// allows; anything else reads as unset.
final class PreferenceRepository {
  PreferenceRepository(this._database);

  final AppDatabase _database;

  Future<String?> read(PreferenceKey key) async => (await (_database.select(
    _database.preferences,
  )..where((table) => table.key.equals(key.name))).getSingleOrNull())?.value;

  Future<void> write(PreferenceKey key, String value) => _database
      .into(_database.preferences)
      .insertOnConflictUpdate(
        PreferencesCompanion.insert(key: key.name, value: value),
      );
}
