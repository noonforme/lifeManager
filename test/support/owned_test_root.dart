import 'dart:io';
import 'dart:math';

import 'package:lifeos/core/database/test_root_guard.dart';

final class OwnedTestRoot {
  OwnedTestRoot._({required this.directory, required this.token});

  final Directory directory;
  final String token;

  Uri get uri => directory.uri;

  static Future<OwnedTestRoot> create({Directory? parent}) async {
    final base = parent ?? Directory.systemTemp;
    final directory = await base.createTemp('lifeos-owned-test-');
    final token = List<int>.generate(
      32,
      (_) => Random.secure().nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await File(
      '${directory.path}${Platform.pathSeparator}${TestRootGuard.markerName}',
    ).writeAsString(token, flush: true);
    return OwnedTestRoot._(directory: directory, token: token);
  }

  Future<void> dispose() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
