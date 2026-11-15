import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/database_config.dart';
import 'package:lifeos/core/database/database_location.dart';
import 'package:lifeos/core/database/test_root_guard.dart';

import '../../support/owned_test_root.dart';

void main() {
  late Directory sandbox;
  late Directory repository;
  late Directory productionSupport;
  late DefaultDatabaseLocation location;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lifeos-location-test-');
    repository = await Directory('${sandbox.path}/repository').create();
    productionSupport = await Directory('${sandbox.path}/production-support')
        .create();
    location = DefaultDatabaseLocation(
      repositoryRoot: repository,
      productionSupportDirectory: () async => productionSupport,
    );
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('resolves a marked owned test root to the fixed filename', () async {
    final root = await OwnedTestRoot.create(parent: sandbox);

    final file = await location.resolve(
      DatabaseConfig.test(root: root.uri, markerToken: root.token),
    );

    expect(file.path, endsWith('lifeos-native-v1.sqlite'));
    expect(_containsPath(repository.path, file.path), isFalse);
    expect(_containsPath(productionSupport.path, file.path), isFalse);
  });

  test('rejects a test root inside the repository', () async {
    final root = await OwnedTestRoot.create(parent: repository);

    await expectLater(
      location.resolve(
        DatabaseConfig.test(root: root.uri, markerToken: root.token),
      ),
      throwsA(isA<UnsafeDataRoot>()),
    );
  });

  test('rejects missing and incorrect ownership markers', () async {
    final ordinary = await Directory('${sandbox.path}/ordinary').create();
    final owned = await OwnedTestRoot.create(parent: sandbox);

    await expectLater(
      location.resolve(
        DatabaseConfig.test(root: ordinary.uri, markerToken: 'owned'),
      ),
      throwsA(isA<UnsafeDataRoot>()),
    );
    await expectLater(
      location.resolve(
        DatabaseConfig.test(root: owned.uri, markerToken: 'wrong'),
      ),
      throwsA(isA<UnsafeDataRoot>()),
    );
  });

  test('rejects the production support root in test mode', () async {
    await File('${productionSupport.path}/${TestRootGuard.markerName}')
        .writeAsString('owned');

    await expectLater(
      location.resolve(
        DatabaseConfig.test(root: productionSupport.uri, markerToken: 'owned'),
      ),
      throwsA(isA<UnsafeDataRoot>()),
    );
  });

  test('rejects a symlink resolving to production support', () async {
    await File('${productionSupport.path}/${TestRootGuard.markerName}')
        .writeAsString('owned');
    final alias = Link('${sandbox.path}/production-alias');
    await alias.create(productionSupport.path);

    await expectLater(
      location.resolve(
        DatabaseConfig.test(root: alias.uri, markerToken: 'owned'),
      ),
      throwsA(isA<UnsafeDataRoot>()),
    );
  });

  test('production resolves only the application support directory', () async {
    final file = await location.resolve(const DatabaseConfig.production());

    expect(
      file.path,
      '${productionSupport.path}/io.lifeos.LifeOS/lifeos-native-v1.sqlite',
    );
  });
}

bool _containsPath(String parent, String child) {
  final canonicalParent = Directory(parent).absolute.path;
  final canonicalChild = File(child).absolute.path;
  return canonicalChild == canonicalParent ||
      canonicalChild.startsWith('$canonicalParent${Platform.pathSeparator}');
}
