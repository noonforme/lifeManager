import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_config.dart';
import 'test_root_guard.dart';

abstract interface class DatabaseLocation {
  Future<File> resolve(DatabaseConfig config);
}

typedef SupportDirectoryProvider = Future<Directory> Function();

final class DefaultDatabaseLocation implements DatabaseLocation {
  DefaultDatabaseLocation({
    Directory? repositoryRoot,
    SupportDirectoryProvider? productionSupportDirectory,
    this._guard = const TestRootGuard(),
  }) : _repositoryRoot = repositoryRoot ?? Directory.current,
       _productionSupportDirectory =
           productionSupportDirectory ?? getApplicationSupportDirectory;

  static const databaseFilename = 'lifeos-native-v1.sqlite';
  static const applicationDirectoryName = 'io.lifeos.LifeOS';

  final Directory _repositoryRoot;
  final SupportDirectoryProvider _productionSupportDirectory;
  final TestRootGuard _guard;

  @override
  Future<File> resolve(DatabaseConfig config) async {
    final productionSupport = await _productionSupportDirectory();
    if (!config.isTest) {
      final applicationDirectory = Directory(
        p.join(productionSupport.path, applicationDirectoryName),
      );
      await applicationDirectory.create(recursive: true);
      await _restrictToOwner(applicationDirectory);
      return File(p.join(applicationDirectory.path, databaseFilename));
    }

    final root = config.root;
    final markerToken = config.markerToken;
    if (root == null || markerToken == null) {
      throw const UnsafeDataRoot();
    }
    final safeRoot = await _guard.validate(
      root: root,
      markerToken: markerToken,
      repositoryRoot: _repositoryRoot,
      productionSupportRoot: productionSupport,
    );
    await _restrictToOwner(safeRoot);
    return File(p.join(safeRoot.path, databaseFilename));
  }

  Future<void> _restrictToOwner(Directory directory) async {
    if (!Platform.isLinux && !Platform.isMacOS) {
      return;
    }
    final result = await Process.run('chmod', ['700', directory.path]);
    if (result.exitCode != 0) {
      throw const UnsafeDataRoot();
    }
  }
}
