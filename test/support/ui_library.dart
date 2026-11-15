import 'dart:io';

final _widgetClass = RegExp(
  r'^(?:(?:final|abstract|base|sealed|interface)\s+)*class\s+([A-Z]\w*)'
  r'(?:<[^{]*?>)?\s+extends\s+(?:StatelessWidget|StatefulWidget|'
  r'InheritedWidget|InheritedNotifier|InheritedModel|ProxyWidget|'
  r'RenderObjectWidget|SingleChildRenderObjectWidget|LeafRenderObjectWidget|'
  r'MultiChildRenderObjectWidget)\b',
  multiLine: true,
);

/// Every public widget class in the UI library (the gallery excluded), with
/// its file relative to `lib/ui/`: `'KeyButton': 'controls/keys.dart'`.
Map<String, String> libraryWidgetClasses() => {
  for (final file in Directory('lib/ui').listSync(recursive: true))
    if (file is File &&
        file.path.endsWith('.dart') &&
        !file.path.startsWith('lib/ui/gallery/'))
      for (final match in _widgetClass.allMatches(file.readAsStringSync()))
        match.group(1)!: file.path.substring('lib/ui/'.length),
};
