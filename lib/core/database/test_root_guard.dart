import 'dart:io';

import 'package:path/path.dart' as p;

final class UnsafeDataRoot implements Exception {
  const UnsafeDataRoot();
}

final class TestRootGuard {
  const TestRootGuard();

  static const markerName = '.lifeos-test-root';

  Future<Directory> validate({
    required Uri root,
    required String markerToken,
    required Directory repositoryRoot,
    required Directory productionSupportRoot,
  }) async {
    if (!root.isScheme('file') || markerToken.isEmpty) {
      throw const UnsafeDataRoot();
    }

    final candidate = Directory.fromUri(root);
    final canonicalCandidate = await _canonicalDirectory(candidate);
    final canonicalRepository = await _canonicalDirectory(repositoryRoot);
    final canonicalProduction = await _canonicalDirectory(
      productionSupportRoot,
    );

    if (_contains(canonicalRepository.path, canonicalCandidate.path) ||
        _contains(canonicalProduction.path, canonicalCandidate.path)) {
      throw const UnsafeDataRoot();
    }

    final marker = File(p.join(canonicalCandidate.path, markerName));
    if (!await marker.exists()) {
      throw const UnsafeDataRoot();
    }
    final actualToken = await marker.readAsString();
    if (actualToken != markerToken) {
      throw const UnsafeDataRoot();
    }

    return canonicalCandidate;
  }

  Future<Directory> _canonicalDirectory(Directory directory) async {
    if (!await directory.exists()) {
      throw const UnsafeDataRoot();
    }
    return Directory(await directory.resolveSymbolicLinks());
  }

  bool _contains(String parent, String child) {
    final normalizedParent = p.normalize(p.absolute(parent));
    final normalizedChild = p.normalize(p.absolute(child));
    return normalizedChild == normalizedParent ||
        p.isWithin(normalizedParent, normalizedChild);
  }
}
