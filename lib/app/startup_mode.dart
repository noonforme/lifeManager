/// Whether a `LIFEOS_GALLERY` define selects the gallery. The launcher
/// passes the exact value 1; anything else starts LifeOS.
bool isGalleryRequested(String define) => define == '1';

/// bool.fromEnvironment would read the launcher's 1 as false, falling
/// through to production startup.
final galleryRequested = isGalleryRequested(
  const String.fromEnvironment('LIFEOS_GALLERY'),
);

/// Runs the mode the launcher selected: the gallery, else LifeOS.
Future<void> startSelectedMode({
  required Future<void> Function() startGallery,
  required Future<void> Function() startProduction,
}) {
  if (galleryRequested) return startGallery();
  return startProduction();
}
