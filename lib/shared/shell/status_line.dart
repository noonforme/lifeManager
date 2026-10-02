import 'package:flutter/widgets.dart';

import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';

/// A running shift as the status line shows it.
@immutable
final class RunningShiftStatus {
  const RunningShiftStatus({required this.label, required this.onOpen});

  /// For example "Shift running since 07:02".
  final String label;
  final VoidCallback onOpen;
}

/// What the status line reports (spec 5.4). Segments appear only for facts
/// LifeOS actually has; nothing is shown as a placeholder.
@immutable
final class StatusSnapshot {
  const StatusSnapshot({
    this.runningShift,
    this.needsYou = 0,
    this.openDrafts = 0,
    this.lastSave,
    this.lastSaveUncertain = false,
  });

  final RunningShiftStatus? runningShift;
  final int needsYou;
  final int openDrafts;

  /// Local time of the last committed change, when known.
  final String? lastSave;

  /// The last save could not be confirmed.
  final bool lastSaveUncertain;
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
    final running = snapshot.runningShift;
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
            Expanded(
              child: running == null
                  ? const SizedBox.shrink()
                  : _Panel(
                      onTap: running.onOpen,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: tokens.signal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              running.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: style.copyWith(color: tokens.runInk),
                            ),
                          ),
                        ],
                      ),
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
  const _Panel({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    final panel = Container(
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
    if (onTap == null) return panel;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: panel),
      ),
    );
  }
}
