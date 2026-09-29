final class DatabaseConfig {
  const DatabaseConfig.production() : root = null, markerToken = null;

  const DatabaseConfig.test({required this.root, required this.markerToken});

  final Uri? root;
  final String? markerToken;

  bool get isTest => root != null;
}
