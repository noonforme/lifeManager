import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/streams/watch_reads.dart';

void main() {
  test(
    'an initial read cannot miss an invalidation and bursts coalesce',
    () async {
      final updates = StreamController<Object?>.broadcast(sync: true);
      addTearDown(updates.close);
      final held = Completer<int>();
      var reads = 0;
      final values = <int>[];
      final subscription = watchReads<int>(updates.stream, () async {
        reads++;
        return reads == 1 ? held.future : reads;
      }).listen(values.add);
      await pumpEventQueue();
      expect(updates.hasListener, isTrue);
      for (var i = 0; i < 20; i++) {
        updates.add(null);
      }
      held.complete(1);
      await pumpEventQueue();
      expect(reads, 2);
      expect(values, [1, 2]);
      for (var i = 0; i < 20; i++) {
        updates.add(null);
      }
      await pumpEventQueue();
      expect(reads, 3);
      expect(values.last, 3);
      await subscription.cancel();
      expect(updates.hasListener, isFalse);
    },
  );

  test('a failed read reports once and a later update recovers', () async {
    final updates = StreamController<Object?>.broadcast(sync: true);
    addTearDown(updates.close);
    var fail = true;
    final values = <int>[];
    final errors = <Object>[];
    final subscription = watchReads<int>(updates.stream, () async {
      if (fail) throw StateError('synthetic unreadable');
      return 2;
    }).listen(values.add, onError: errors.add);
    await pumpEventQueue();
    expect(errors, hasLength(1));
    fail = false;
    updates.add(null);
    await pumpEventQueue();
    expect(values, [2]);
    await subscription.cancel();
  });

  test('late observers replay the shared value; after last cancel a fresh read runs', () async {
    final updates = StreamController<Object?>.broadcast(sync: true);
    addTearDown(updates.close);
    var reads = 0;
    final shared = shareLatest(
      () => watchReads(updates.stream, () async => ++reads),
    );
    final a = <int>[];
    final b = <int>[];
    final first = shared.listen(a.add);
    await pumpEventQueue();
    final second = shared.listen(b.add);
    await pumpEventQueue();
    expect(reads, 1);
    expect(a, [1]);
    expect(b, [1]);
    await first.cancel();
    updates.add(null);
    await pumpEventQueue();
    expect(b, [1, 2]);
    await second.cancel();
    expect(updates.hasListener, isFalse);
    expect(await shared.first, 3);
  });
}
