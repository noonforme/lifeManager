import 'package:flutter/foundation.dart';
import 'package:lifeos/shared/shell/era_window_frame.dart';

/// Records what the painted frame asks of the window.
final class FakeWindowControls implements WindowControls {
  final calls = <String>[];
  final _state = ValueNotifier(const WindowFrameState());

  @override
  ValueListenable<WindowFrameState> get state => _state;

  set frame(WindowFrameState value) => _state.value = value;

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> toggleMaximize() async => calls.add('toggleMaximize');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> startDragging() async => calls.add('drag');

  @override
  Future<void> startResizing(WindowEdge edge) async =>
      calls.add('resize $edge');

  @override
  Future<void> setTitle(String title) async => calls.add('title $title');
}
