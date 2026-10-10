import 'package:flutter/material.dart';

import '../ui.dart';
import 'gallery_demo.dart';

/// The app around the gallery: the LifeOS theme, skin, era scrolling and
/// cell selection, as the real app provides them. Synthetic only; it opens
/// no database.
final class GalleryHost extends StatefulWidget {
  const GalleryHost({required this.home, super.key});

  final Widget home;

  @override
  State<GalleryHost> createState() => _GalleryHostState();
}

final class _GalleryHostState extends State<GalleryHost> {
  final _cells = CellSelectionController();

  @override
  void dispose() {
    _cells.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LifeOS widget gallery',
    debugShowCheckedModeBanner: false,
    theme: buildLifeOSTheme(),
    scrollBehavior: const EraScrollBehavior(),
    builder: (context, child) => CellSelectionScope(
      controller: _cells,
      child: LifeOSSkinScope(
        child: Builder(
          builder: (context) => Theme(
            data: lifeOSThemeFor(LifeOSSkinScope.of(context)),
            // Text fields need a Material ancestor; it paints nothing.
            child: Material(
              type: MaterialType.transparency,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
    home: widget.home,
  );
}

/// One demo on the property-sheet page colour, under its knobs: text scale,
/// and Enabled for every era field through [EraFormScope]. Scrolls when the
/// bounded demo surface is larger than the viewport in either axis.
final class GalleryCanvas extends StatelessWidget {
  const GalleryCanvas({required this.demo, required this.knobs, super.key});

  final GalleryDemo demo;
  final GalleryKnobs knobs;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ColoredBox(
      color: MillenniumColors.page,
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(knobs.textScale)),
        child: EraFormScope(
          enabled: knobs.enabled,
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              // The horizontal era scrollbar stacks under its content and
              // needs a bounded height: the demo's, plus the 17 px bar when
              // the demo is wider than the canvas.
              child: SizedBox(
                height:
                    demo.size.height * knobs.textScale +
                    (demo.size.width * knobs.textScale > viewport.maxWidth
                        ? 17
                        : 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: demo.size.width * knobs.textScale,
                    height: demo.size.height * knobs.textScale,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Builder(
                          builder: (context) => demo.build(context, knobs),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
