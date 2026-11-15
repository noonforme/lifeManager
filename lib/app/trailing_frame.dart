import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Draws one more frame after the last frame of every change.
///
/// On the owner's desktop (KDE Plasma on Wayland, an NVIDIA card) the
/// window shows each frame only once the next one is drawn. A real mouse
/// proved it (bead lifeManager-7qj): a click on the calendar's ▸ drew one
/// frame and committed one buffer, and the screen kept the month before
/// until something else repainted, so ▸ seemed dead and then jumped. Tests
/// cannot see it; the engine and driver below the app cause it. A trailing
/// frame that changes nothing pushes the last change to the screen, at the
/// cost of one frame after each burst; an idle window still draws nothing.
mixin TrailingFrame on SchedulerBinding {
  /// Whether the frame now scheduled was asked for only as a trailing one.
  bool _trailingScheduled = false;

  /// Whether the frame being drawn is such a trailing frame.
  bool _drawingTrailing = false;

  /// Any other request carries a change, so that frame is not trailing.
  @override
  void scheduleFrame() {
    _trailingScheduled = false;
    super.scheduleFrame();
  }

  @override
  void scheduleForcedFrame() {
    _trailingScheduled = false;
    super.scheduleForcedFrame();
  }

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    _drawingTrailing = _trailingScheduled;
    _trailingScheduled = false;
    super.handleBeginFrame(rawTimeStamp);
  }

  /// After a frame with a change, when nothing else asked for a frame,
  /// asks for the trailing one; after the trailing frame, for none.
  @override
  void handleDrawFrame() {
    super.handleDrawFrame();
    if (_drawingTrailing) {
      _drawingTrailing = false;
      return;
    }
    if (!hasScheduledFrame) {
      super.scheduleFrame();
      _trailingScheduled = hasScheduledFrame;
    }
  }
}

/// Flutter's own binding with [TrailingFrame]. Made once, before
/// WidgetsFlutterBinding.ensureInitialized, which then keeps it.
final class TrailingFrameBinding extends WidgetsFlutterBinding
    with TrailingFrame {}
