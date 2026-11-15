import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controls/era_controls.dart';
import '../controls/era_scrollbar.dart';
import '../controls/keys.dart';
import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';
import 'era_dialog.dart';

/// The sign beside a confirmation's message.
enum ConfirmSign {
  /// The painted warning mark: the action loses or replaces something.
  warning,

  /// A painted information mark: the window only reports.
  info,
}

/// One answer a [ConfirmWindow] offers: the typed [value] it reports and the
/// key's [label].
@immutable
final class ConfirmChoice<T> {
  const ConfirmChoice({
    required this.value,
    required this.label,
    this.semanticLabel,
  });

  final T value;
  final String label;

  /// Announced instead of [label], for example when the label is short.
  final String? semanticLabel;
}

/// A modal-style confirmation in the era's window shape: a blue caption with
/// a red close key, a [sign] and a [message], and two or three keys in a
/// wrapping row. The first choice is the affirmative one.
///
/// Mouse-operated: nothing in it takes keyboard focus, so Enter and Space
/// activate nothing. The window reports through [onChoose] only; it neither
/// closes itself nor saves anything. The close key chooses [cancelValue],
/// which the owner states outright (it may equal one of the [choices], for
/// example a "Keep editing" key) rather than the window guessing a safe
/// answer. [showConfirmWindow] hosts one in a modal route.
///
/// It fits the space it is given: it never exceeds the parent's bounds, the
/// keys wrap and a long message scrolls. It is not movable and holds no form
/// fields. [enabled] false greys the keys and the close key and makes them
/// inert.
final class ConfirmWindow<T> extends StatefulWidget {
  ConfirmWindow({
    required this.title,
    required this.message,
    required this.choices,
    required this.cancelValue,
    required this.onChoose,
    this.sign = ConfirmSign.warning,
    this.enabled = true,
    super.key,
  }) : assert(
         choices.length >= 2 && choices.length <= 3,
         'A confirmation offers two or three choices.',
       ),
       assert(
         choices.map((choice) => choice.value).toSet().length == choices.length,
         'Choice values must be distinct.',
       );

  final String title;
  final String message;

  /// Two or three choices; the first is the affirmative one.
  final List<ConfirmChoice<T>> choices;

  /// What the close key reports; an explicit cancellation, not a guess.
  final T cancelValue;

  /// A choice, or [cancelValue] from the close key. Not called while
  /// [enabled] is false.
  final ValueChanged<T> onChoose;
  final ConfirmSign sign;
  final bool enabled;

  @override
  State<ConfirmWindow<T>> createState() => _ConfirmWindowState<T>();
}

final class _ConfirmWindowState<T> extends State<ConfirmWindow<T>> {
  final _scroll = ScrollController();
  final _footerScroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    _footerScroll.dispose();
    super.dispose();
  }

  void _choose(T value) {
    if (widget.enabled) widget.onChoose(value);
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wider with larger text so a key's label is not cut; never wider
        // than the space given.
        final width = math.min(scaler.scale(420), constraints.maxWidth);
        final bounded = constraints.hasBoundedHeight;
        final message = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SignMark(widget.sign),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                style: skin.typography.body.copyWith(color: tokens.ink),
              ),
            ),
          ],
        );
        final scrolled = EraScrollbar(
          controller: _scroll,
          axis: Axis.vertical,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: SingleChildScrollView(controller: _scroll, child: message),
          ),
        );
        final body = Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: bounded ? scrolled : message,
        );
        final keys = Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: FormFooter(
            children: [
              for (final (index, choice) in widget.choices.indexed)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.max(0, width - 24),
                  ),
                  child: KeyButton(
                    label: choice.label,
                    wrapLabel: true,
                    semanticLabel: choice.semanticLabel,
                    kind: index == 0 ? KeyKind.primary : KeyKind.secondary,
                    onPressed: widget.enabled
                        ? () => _choose(choice.value)
                        : null,
                  ),
                ),
            ],
          ),
        );
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: math.min(280, width),
              maxWidth: width,
              maxHeight: constraints.maxHeight,
            ),
            child: Material(
              color: tokens.chrome,
              shape: const RoundedRectangleBorder(
                side: BorderSide(color: MillenniumColors.keyLine),
                borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
              ),
              clipBehavior: Clip.antiAlias,
              // Named by its caption, as every era window is.
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: widget.title,
                // Mouse only: no part of the window is a keyboard target.
                child: ExcludeFocus(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CaptionBar(
                        title: widget.title,
                        large: true,
                        closeEnabled: widget.enabled,
                        onClose: () => _choose(widget.cancelValue),
                      ),
                      if (bounded) Flexible(child: body) else body,
                      if (bounded)
                        // Pinned, but never more than half the height: past that
                        // the keys scroll on their own.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight / 2,
                          ),
                          child: EraScrollbar(
                            controller: _footerScroll,
                            axis: Axis.vertical,
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(scrollbars: false),
                              child: SingleChildScrollView(
                                controller: _footerScroll,
                                child: keys,
                              ),
                            ),
                          ),
                        )
                      else
                        keys,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows a [ConfirmWindow] over the current page in a modal route and
/// completes with the chosen value, or [cancelValue] from the close key.
///
/// The route is mouse-operated: its barrier is not dismissible and a tap on
/// it does nothing; every key is consumed, so none reaches an editor under
/// the route and none activates a choice; there is no animation and no
/// shadow. The caller's theme and skin are carried across the route.
Future<T> showConfirmWindow<T>(
  BuildContext context, {
  required String title,
  required String message,
  required List<ConfirmChoice<T>> choices,
  required T cancelValue,
  ConfirmSign sign = ConfirmSign.warning,
  bool useRootNavigator = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final chosen = await navigator.push<T>(
    RawDialogRoute<T>(
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: const Color(0x00000000),
      transitionDuration: Duration.zero,
      settings: const RouteSettings(name: 'confirm-window'),
      pageBuilder: (routeContext, _, _) => themes.wrap(
        LifeOSSkinScope(
          child: _ConfirmRoute(
            // A Material and text-style context, as a dialog route has.
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConfirmWindow<T>(
                title: title,
                message: message,
                choices: choices,
                cancelValue: cancelValue,
                sign: sign,
                onChoose: (value) => Navigator.of(routeContext).pop(value),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return chosen ?? cancelValue;
}

/// Holds focus for the route and consumes every key, so a key cannot reach an
/// editor under the route, a choice or an application shortcut.
final class _ConfirmRoute extends StatelessWidget {
  const _ConfirmRoute({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Focus(
      autofocus: true,
      onKeyEvent: (_, KeyEvent event) => KeyEventResult.handled,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: LifeOSSkinScope.of(context).typography.body,
          child: child,
        ),
      ),
    ),
  );
}

/// The painted sign: the library's warning mark, or a blue disc with a
/// painted "i".
final class _SignMark extends StatelessWidget {
  const _SignMark(this.sign);

  final ConfirmSign sign;

  @override
  Widget build(BuildContext context) => switch (sign) {
    ConfirmSign.warning => const EraIcon(EraIconKind.warning, size: 32),
    ConfirmSign.info => const SizedBox.square(
      dimension: 32,
      child: CustomPaint(painter: _InfoPainter()),
    ),
  };
}

final class _InfoPainter extends CustomPainter {
  const _InfoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2 - 1;
    canvas
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MillenniumColors.captionTop,
              MillenniumColors.captionBottom,
            ],
          ).createShader(Offset.zero & size),
      )
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = MillenniumColors.keyLine,
      );
    final white = Paint()..color = const Color(0xffffffff);
    final u = size.width / 16;
    canvas
      ..drawCircle(Offset(centre.dx, 4.5 * u), 1.6 * u, white)
      ..drawRect(Rect.fromLTWH(6.6 * u, 7.2 * u, 2.8 * u, 5.6 * u), white);
  }

  @override
  bool shouldRepaint(_InfoPainter oldDelegate) => false;
}
