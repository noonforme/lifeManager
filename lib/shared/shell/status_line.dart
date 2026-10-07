import 'package:flutter/widgets.dart';

import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';

/// What the status line reports (spec 5.4). Segments appear only for facts
/// LifeOS actually has; nothing is shown as a placeholder.
@immutable
final class StatusSnapshot {
  const StatusSnapshot({
    this.needsYou = 0,
    this.daysToConfirm = 0,
    this.openDrafts = 0,
    this.lastSave,
    this.lastSaveUncertain = false,
  });

  final int needsYou;

  /// Past planned days not yet confirmed (schedules spec 5).
  final int daysToConfirm;
  final int openDrafts;

  /// Local time of the last committed change, when known.
  final String? lastSave;

  /// The last save could not be confirmed.
  final bool lastSaveUncertain;
}

/// What the last finished action did, for the status bar's first panel
/// ("Shift saved."). It stays until the next notice replaces it.
final class StatusNoticeController extends ValueNotifier<String?> {
  StatusNoticeController() : super(null);
}

final class StatusNoticeScope
    extends InheritedNotifier<StatusNoticeController> {
  const StatusNoticeScope({
    required StatusNoticeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static String? valueOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<StatusNoticeScope>()
      ?.notifier
      ?.value;

  static StatusNoticeController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StatusNoticeScope>()?.notifier;
}

/// What the lit menu row or key does, shown in the status bar's first
/// panel while it is lit, as the era described a command before you chose
/// it. Null gives the panel back to the last notice.
final class StatusHintController extends ValueNotifier<String?> {
  StatusHintController() : super(null);
}

final class StatusHintScope extends InheritedNotifier<StatusHintController> {
  const StatusHintScope({
    required StatusHintController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static String? valueOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<StatusHintScope>()
      ?.notifier
      ?.value;

  static StatusHintController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StatusHintScope>()?.notifier;
}

/// The sunken status bar at the bottom of the shell.
final class StatusLine extends StatelessWidget {
  const StatusLine({required this.snapshot, super.key});

  final StatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final style = skin.typography.small.copyWith(color: tokens.ink);
    final notice =
        StatusHintScope.valueOf(context) ?? StatusNoticeScope.valueOf(context);
    final save = snapshot.lastSaveUncertain
        ? 'Last save uncertain. Reload to check'
        : snapshot.lastSave == null
        ? 'Local database'
        : 'Local database · saved ${snapshot.lastSave}';
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.chrome,
        border: Border(top: BorderSide(color: tokens.paper)),
      ),
      // Panels share the tallest panel's height at any text size.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The first panel stretches and says what was just done.
            Expanded(
              child: notice == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      liveRegion: true,
                      child: _Panel(child: Text(notice, style: style)),
                    ),
            ),
            if (snapshot.daysToConfirm > 0)
              _Panel(
                child: Text(
                  snapshot.daysToConfirm == 1
                      ? '1 day to confirm'
                      : '${snapshot.daysToConfirm} days to confirm',
                  style: style,
                ),
              ),
            if (snapshot.needsYou > 0)
              _Panel(
                child: Text('Needs you: ${snapshot.needsYou}', style: style),
              ),
            if (snapshot.openDrafts > 0)
              _Panel(
                child: Text(
                  snapshot.openDrafts == 1
                      ? '1 draft'
                      : '${snapshot.openDrafts} drafts',
                  style: style,
                ),
              ),
            _Panel(
              child: Text(
                save,
                style: snapshot.lastSaveUncertain
                    ? style.copyWith(color: tokens.negative)
                    : style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sunken status panel: dark top-left edge, white bottom-right edge.
final class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Container(
      key: const ValueKey('status-panel'),
      margin: const EdgeInsets.only(left: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: MillenniumColors.sunkenEdge),
          left: const BorderSide(color: MillenniumColors.sunkenEdge),
          bottom: BorderSide(color: tokens.paper),
          right: BorderSide(color: tokens.paper),
        ),
      ),
      child: child,
    );
  }
}
