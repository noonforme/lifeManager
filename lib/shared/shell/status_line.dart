import 'package:flutter/widgets.dart';

import '../workbench/lifeos_skin.dart';

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

/// The black strip at the bottom of the shell.
final class StatusLine extends StatelessWidget {
  const StatusLine({required this.snapshot, super.key});

  final StatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final paint = skin.painters.statusLine(skin.tokens);
    final style = skin.typography.small.copyWith(color: paint.ink);
    final running = snapshot.runningShift;
    final save = snapshot.lastSaveUncertain
        ? 'Last save uncertain. Reload to check'
        : snapshot.lastSave == null
        ? 'Local database'
        : 'Local database · saved ${snapshot.lastSave}';
    return Container(
      height: 24,
      decoration: paint.fill,
      child: Row(
        children: [
          if (running != null)
            _Segment(
              onTap: running.onOpen,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: paint.indicator,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(running.label, style: style),
                ],
              ),
            ),
          if (snapshot.needsYou > 0)
            _Segment(
              child: Text('Needs you: ${snapshot.needsYou}', style: style),
            ),
          if (snapshot.openDrafts > 0)
            _Segment(
              child: Text(
                snapshot.openDrafts == 1
                    ? '1 draft'
                    : '${snapshot.openDrafts} drafts',
                style: style,
              ),
            ),
          const Spacer(),
          _Segment(
            trailing: true,
            child: Text(
              save,
              style: snapshot.lastSaveUncertain
                  ? style.copyWith(color: paint.alertInk)
                  : style,
            ),
          ),
        ],
      ),
    );
  }
}

final class _Segment extends StatelessWidget {
  const _Segment({required this.child, this.onTap, this.trailing = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final divider = BorderSide(
      color: skin.painters.statusLine(skin.tokens).divider,
    );
    final segment = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: trailing ? Border(left: divider) : Border(right: divider),
      ),
      child: child,
    );
    if (onTap == null) return segment;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: segment),
      ),
    );
  }
}
