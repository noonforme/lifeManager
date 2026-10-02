import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/local_date.dart';
import 'journal_projection.dart';
import 'journal_source.dart';

final journalSourceProvider = Provider<JournalSource>(
  (ref) => const _EmptyJournal(),
);

final class _EmptyJournal implements JournalSource {
  const _EmptyJournal();

  @override
  Stream<List<JournalEntry>> watch(LocalDate from, LocalDate to) =>
      Stream.value(const []);
}

/// The Journal's dates; the route carries only these.
final class JournalRange {
  const JournalRange({required this.from, required this.to});

  /// The last seven days up to [today].
  factory JournalRange.lastWeek(LocalDate today) =>
      JournalRange(from: _addDays(today, -6), to: today);

  final LocalDate from;
  final LocalDate to;

  int get days =>
      DateTime.utc(
        to.year,
        to.month,
        to.day,
      ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
      1;

  /// The range of the same length, [direction] lengths away.
  JournalRange step(int direction) => JournalRange(
    from: _addDays(from, days * direction),
    to: _addDays(to, days * direction),
  );

  Uri get uri => Uri(path: '/journal', query: 'from=$from&to=$to');

  /// The range a Journal route names, or null when it names none or a bad
  /// one.
  static JournalRange? fromUri(Uri uri) {
    final from = LocalDate.tryParse(uri.queryParameters['from'] ?? '');
    final to = LocalDate.tryParse(uri.queryParameters['to'] ?? '');
    if (from == null || to == null || to.compareTo(from) < 0) return null;
    return JournalRange(from: from, to: to);
  }

  @override
  bool operator ==(Object other) =>
      other is JournalRange && from == other.from && to == other.to;

  @override
  int get hashCode => Object.hash(from, to);
}

final journalEntriesProvider = StreamProvider.autoDispose
    .family<List<JournalEntry>, JournalRange>(
      (ref, range) =>
          ref.watch(journalSourceProvider).watch(range.from, range.to),
    );

LocalDate _addDays(LocalDate date, int days) {
  final value = DateTime.utc(date.year, date.month, date.day + days);
  return LocalDate(value.year, value.month, value.day);
}
