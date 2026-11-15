import 'dart:io';

import 'package:path/path.dart' as p;

/// Where the Work shell keeps the last resolved place between runs (spec
/// 4.5, 4.8): one route, written when the window closes.
abstract interface class LocationStore {
  /// The route last written; null when none was, or it cannot be read.
  Future<String?> read();

  Future<void> write(String route);
}

/// A [LocationStore] in a text file. No schema change (spec 8).
final class FileLocationStore implements LocationStore {
  FileLocationStore(this.file);

  /// The place file beside the [database] file.
  factory FileLocationStore.beside(File database) =>
      FileLocationStore(File(p.join(database.parent.path, placeFilename)));

  /// The last place's file name.
  static const placeFilename = 'last-location.txt';

  final File file;

  @override
  Future<String?> read() async {
    try {
      final text = (await file.readAsString()).trim();
      return text.isEmpty ? null : text;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String route) => file.writeAsString(route, flush: true);
}

/// A [LocationStore] in memory, for tests and the gallery.
final class MemoryLocationStore implements LocationStore {
  MemoryLocationStore([this.route]);

  String? route;

  @override
  Future<String?> read() async => route;

  @override
  Future<void> write(String route) async => this.route = route;
}
