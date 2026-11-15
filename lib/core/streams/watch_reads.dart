import 'dart:async';

/// Subscribe before reading. Bursts queue one refresh; invalidation during
/// a read guarantees one trailing refresh, never concurrent reads.
Stream<T> watchReads<T>(Stream<Object?> updates, Future<T> Function() read) {
  late final StreamController<T> out;
  StreamSubscription<Object?>? watching;
  var cancelled = false;
  var queued = false;
  var reading = false;
  var again = false;
  void request() {
    if (cancelled) return;
    if (reading) {
      again = true;
      return;
    }
    if (queued) return;
    queued = true;
    scheduleMicrotask(() async {
      queued = false;
      if (cancelled) return;
      reading = true;
      do {
        again = false;
        try {
          final value = await read();
          if (!cancelled) out.add(value);
        } catch (error, stack) {
          if (!cancelled) out.addError(error, stack);
        }
      } while (again && !cancelled);
      reading = false;
    });
  }

  out = StreamController<T>(
    onListen: () {
      watching = updates.listen((_) => request(), onError: out.addError);
      request();
    },
    onCancel: () async {
      cancelled = true;
      await watching?.cancel();
    },
  );
  return out.stream;
}

/// Share one source while observed, replaying its current value to a late
/// listener. The last cancellation drops the cache and the subscription;
/// a later observer performs a fresh read rather than seeing stale data.
Stream<T> shareLatest<T>(Stream<T> Function() create) {
  late final StreamController<T> hub;
  StreamSubscription<T>? upstream;
  T? latest;
  var hasLatest = false;
  var epoch = 0;
  hub = StreamController<T>.broadcast(
    sync: true,
    onListen: () {
      final mine = ++epoch;
      upstream = create().listen(
        (value) {
          if (mine != epoch) return;
          latest = value;
          hasLatest = true;
          hub.add(value);
        },
        onError: (Object error, StackTrace stack) {
          if (mine != epoch) return;
          hasLatest = false;
          hub.addError(error, stack);
        },
      );
    },
    onCancel: () {
      epoch++;
      hasLatest = false;
      latest = null;
      unawaited(upstream?.cancel());
      upstream = null;
    },
  );
  return Stream<T>.multi((out) {
    final subscription = hub.stream.listen(out.add, onError: out.addError);
    if (hasLatest) out.add(latest as T);
    out.onCancel = subscription.cancel;
  }, isBroadcast: true);
}
