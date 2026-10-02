import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/desks/desk_repository.dart';
import '../core/desks/desks.dart';
import '../core/desks/saved_view_repository.dart';
import '../core/desks/saved_views.dart';

/// Desks, or null where no database backs them (some tests).
final deskRepositoryProvider = Provider<DeskRepository?>((ref) => null);

/// Every desk in tab order. The starter desks are created on first read.
final desksProvider = StreamProvider.autoDispose<List<Desk>>((ref) async* {
  final desks = ref.watch(deskRepositoryProvider);
  if (desks == null) {
    yield const [];
    return;
  }
  await desks.ensureStarters();
  yield* desks.watchDesks();
});

/// Saved views, or null where no database backs them (some tests).
final savedViewRepositoryProvider = Provider<SavedViewRepository?>(
  (ref) => null,
);

/// Every saved view in the order saved.
final savedViewsProvider = StreamProvider.autoDispose<List<SavedView>>((ref) {
  final views = ref.watch(savedViewRepositoryProvider);
  return views == null ? Stream.value(const []) : views.watchViews();
});
