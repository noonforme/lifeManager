import 'package:flutter/widgets.dart';

import 'gallery_app.dart';

/// Starts the widget gallery instead of LifeOS (`./app.sh` › Open widget
/// gallery, `--dart-define=LIFEOS_GALLERY=1`). It shows synthetic data only
/// and never opens a database.
Future<void> runGallery({
  required Future<void> Function() prepareWindow,
  required Future<void> Function() showWindow,
  void Function(Widget app) mount = runApp,
}) async {
  await prepareWindow();
  mount(const GalleryApp());
  await showWindow();
}
