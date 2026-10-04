import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../workbench/era_controls.dart';
import '../workbench/era_icons.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';

enum WindowEdge {
  top,
  bottom,
  left,
  right,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

@immutable
final class WindowFrameState {
  const WindowFrameState({this.maximized = false, this.active = true});

  final bool maximized;
  final bool active;

  @override
  bool operator ==(Object other) =>
      other is WindowFrameState &&
      other.maximized == maximized &&
      other.active == active;

  @override
  int get hashCode => Object.hash(maximized, active);
}

/// What the painted caption asks of the real window.
abstract interface class WindowControls {
  ValueListenable<WindowFrameState> get state;
  Future<void> minimize();
  Future<void> toggleMaximize();
  Future<void> close();
  Future<void> startDragging();
  Future<void> startResizing(WindowEdge edge);
  Future<void> setTitle(String title);
}

/// A frame with no window behind it, for tests and goldens.
final class InertWindowControls implements WindowControls {
  InertWindowControls();

  final _state = ValueNotifier(const WindowFrameState());

  @override
  ValueListenable<WindowFrameState> get state => _state;

  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> startDragging() async {}

  @override
  Future<void> startResizing(WindowEdge edge) async {}

  @override
  Future<void> setTitle(String title) async {}
}

final class WindowControlsScope extends InheritedWidget {
  const WindowControlsScope({
    required this.controls,
    required super.child,
    super.key,
  });

  final WindowControls controls;

  static WindowControls? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WindowControlsScope>()
      ?.controls;

  @override
  bool updateShouldNotify(WindowControlsScope oldWidget) =>
      controls != oldWidget.controls;
}

/// The current location's name for the caption ("Shifts").
final class WindowTitleController extends ValueNotifier<String?> {
  WindowTitleController() : super(null);
}

final class WindowTitleScope extends InheritedNotifier<WindowTitleController> {
  const WindowTitleScope({
    required WindowTitleController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static WindowTitleController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WindowTitleScope>()?.notifier;
}

/// The window as the era drew it (XP-authentic shell spec 5): a blue frame
/// and caption around the app, with LifeOS's own caption keys.
final class EraWindowFrame extends StatefulWidget {
  const EraWindowFrame({
    required this.controls,
    required this.title,
    required this.child,
    super.key,
  });

  final WindowControls controls;
  final WindowTitleController title;
  final Widget child;

  static const border = 4.0;
  static const captionHeight = 30.0;

  @override
  State<EraWindowFrame> createState() => _EraWindowFrameState();
}

final class _EraWindowFrameState extends State<EraWindowFrame> {
  String _caption() {
    final title = widget.title.value;
    return title == null ? 'LifeOS' : '$title - LifeOS';
  }

  void _syncTitle() {
    widget.controls.setTitle(_caption());
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.title.addListener(_syncTitle);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.controls.setTitle(_caption()),
    );
  }

  @override
  void didUpdateWidget(covariant EraWindowFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      oldWidget.title.removeListener(_syncTitle);
      widget.title.addListener(_syncTitle);
    }
  }

  @override
  void dispose() {
    widget.title.removeListener(_syncTitle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controls = widget.controls;
    return WindowControlsScope(
      controls: controls,
      child: WindowTitleScope(
        controller: widget.title,
        child: ValueListenableBuilder<WindowFrameState>(
          valueListenable: controls.state,
          builder: (context, state, _) {
            final edge = state.maximized ? 0.0 : EraWindowFrame.border;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: state.active
                    ? MillenniumColors.frameActive
                    : MillenniumColors.frameInactive,
                borderRadius: state.maximized
                    ? null
                    : const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(edge, 0, edge, edge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Caption(
                          title: _caption(),
                          state: state,
                          controls: controls,
                        ),
                        Expanded(child: widget.child),
                      ],
                    ),
                  ),
                  if (!state.maximized) ..._edges(controls),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _edges(WindowControls controls) {
    const b = EraWindowFrame.border;
    const corner = 12.0;
    Widget edge(
      WindowEdge which,
      SystemMouseCursor cursor, {
      double? left,
      double? top,
      double? right,
      double? bottom,
      double? width,
      double? height,
    }) => Positioned(
      key: ValueKey('window-edge-${which.name}'),
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => controls.startResizing(which),
        ),
      ),
    );
    return [
      edge(
        WindowEdge.top,
        SystemMouseCursors.resizeUp,
        left: corner,
        right: corner,
        top: 0,
        height: b,
      ),
      edge(
        WindowEdge.bottom,
        SystemMouseCursors.resizeDown,
        left: corner,
        right: corner,
        bottom: 0,
        height: b,
      ),
      edge(
        WindowEdge.left,
        SystemMouseCursors.resizeLeft,
        left: 0,
        top: corner,
        bottom: corner,
        width: b,
      ),
      edge(
        WindowEdge.right,
        SystemMouseCursors.resizeRight,
        right: 0,
        top: corner,
        bottom: corner,
        width: b,
      ),
      edge(
        WindowEdge.topLeft,
        SystemMouseCursors.resizeUpLeft,
        left: 0,
        top: 0,
        width: corner,
        height: b,
      ),
      edge(
        WindowEdge.topRight,
        SystemMouseCursors.resizeUpRight,
        right: 0,
        top: 0,
        width: corner,
        height: b,
      ),
      edge(
        WindowEdge.bottomLeft,
        SystemMouseCursors.resizeDownLeft,
        left: 0,
        bottom: 0,
        width: corner,
        height: corner,
      ),
      edge(
        WindowEdge.bottomRight,
        SystemMouseCursors.resizeDownRight,
        right: 0,
        bottom: 0,
        width: corner,
        height: corner,
      ),
    ];
  }
}

final class _Caption extends StatelessWidget {
  const _Caption({
    required this.title,
    required this.state,
    required this.controls,
  });

  final String title;
  final WindowFrameState state;
  final WindowControls controls;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final colors = state.active
        ? [
            MillenniumColors.windowCaptionLight,
            MillenniumColors.captionTop,
            tokens.head,
            MillenniumColors.windowCaptionDeep,
          ]
        : const [
            MillenniumColors.inactiveCaptionLight,
            MillenniumColors.inactiveCaption,
            MillenniumColors.inactiveCaption,
            MillenniumColors.frameInactive,
          ];
    return Container(
      height: EraWindowFrame.captionHeight,
      padding: const EdgeInsets.only(left: 6, right: 4),
      decoration: BoxDecoration(
        borderRadius: state.maximized
            ? null
            : const BorderRadius.vertical(top: Radius.circular(8)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: const [0, 0.12, 0.6, 1],
        ),
      ),
      child: Row(
        children: [
          // The icon and title drag the window and double-click to
          // maximize; the caption keys stay plain keys.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => controls.startDragging(),
              onDoubleTap: controls.toggleMaximize,
              child: Row(
                children: [
                  const EraIcon(EraIconKind.app),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: skin.typography.caption.copyWith(
                          color: tokens.headInk,
                          // The era's caption text shadow: the style's one
                          // shadow.
                          shadows: const [
                            Shadow(
                              color: MillenniumColors.captionShadow,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _CaptionKey(
            label: 'Minimize',
            glyph: _CaptionGlyph.minimize,
            faded: !state.active,
            onPressed: controls.minimize,
          ),
          _CaptionKey(
            label: state.maximized ? 'Restore' : 'Maximize',
            glyph: state.maximized
                ? _CaptionGlyph.restore
                : _CaptionGlyph.maximize,
            faded: !state.active,
            onPressed: controls.toggleMaximize,
          ),
          _CaptionKey(
            label: 'Close',
            glyph: _CaptionGlyph.close,
            faded: !state.active,
            onPressed: controls.close,
          ),
        ],
      ),
    );
  }
}

enum _CaptionGlyph { minimize, maximize, restore, close }

final class _CaptionKey extends StatelessWidget {
  const _CaptionKey({
    required this.label,
    required this.glyph,
    required this.faded,
    required this.onPressed,
  });

  final String label;
  final _CaptionGlyph glyph;
  final bool faded;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final close = glyph == _CaptionGlyph.close;
    return EraPressable(
      label: label,
      onPressed: onPressed,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: Opacity(
            opacity: faded ? 0.6 : 1,
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(3)),
                border: Border.all(color: const Color(0xffffffff)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: close
                      ? const [
                          MillenniumColors.closeTop,
                          MillenniumColors.closeBottom,
                        ]
                      : const [
                          MillenniumColors.captionKeyTop,
                          MillenniumColors.captionKeyBottom,
                        ],
                ),
              ),
              child: CustomPaint(painter: _GlyphPainter(glyph)),
            ),
          ),
        ),
      ),
    );
  }
}

final class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph);

  final _CaptionGlyph glyph;

  @override
  void paint(Canvas canvas, Size size) {
    Paint ink(double width) => Paint()
      ..color = const Color(0xffffffff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final w = size.width;
    switch (glyph) {
      case _CaptionGlyph.minimize:
        canvas.drawLine(
          Offset(w * 0.3, w * 0.72),
          Offset(w * 0.6, w * 0.72),
          ink(2),
        );
      case _CaptionGlyph.maximize:
        canvas
          ..drawRect(
            Rect.fromLTRB(w * 0.27, w * 0.27, w * 0.73, w * 0.73),
            ink(1),
          )
          ..drawLine(
            Offset(w * 0.27, w * 0.3),
            Offset(w * 0.73, w * 0.3),
            ink(2),
          );
      case _CaptionGlyph.restore:
        canvas
          ..drawRect(
            Rect.fromLTRB(w * 0.4, w * 0.22, w * 0.76, w * 0.55),
            ink(1),
          )
          ..drawRect(
            Rect.fromLTRB(w * 0.24, w * 0.42, w * 0.6, w * 0.76),
            ink(1),
          );
      case _CaptionGlyph.close:
        canvas
          ..drawLine(Offset(w * 0.3, w * 0.3), Offset(w * 0.7, w * 0.7), ink(2))
          ..drawLine(
            Offset(w * 0.7, w * 0.3),
            Offset(w * 0.3, w * 0.7),
            ink(2),
          );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.glyph != glyph;
}
