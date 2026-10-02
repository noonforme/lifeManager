import 'package:flutter/widgets.dart';

/// Browser-style history of shell locations (spec 6.8). It holds only route
/// strings, which carry structural state and never record content.
final class NavigationHistory extends ChangeNotifier {
  NavigationHistory({this.capacity = 100});

  final int capacity;
  final List<String> _entries = [];
  int _index = -1;
  String? _travelingTo;

  String? get current => _index < 0 ? null : _entries[_index];
  bool get canGoBack => _index > 0;
  bool get canGoForward => _index >= 0 && _index < _entries.length - 1;

  /// Records that the app now shows [location]. A location reached by
  /// [back] or [forward] moves within the history; any other location is a
  /// new step that clears the forward entries.
  void visit(String location) {
    if (_travelingTo == location) {
      _travelingTo = null;
      return;
    }
    _travelingTo = null;
    if (location == current) return;
    if (canGoForward) _entries.removeRange(_index + 1, _entries.length);
    _entries.add(location);
    if (_entries.length > capacity) _entries.removeAt(0);
    _index = _entries.length - 1;
    notifyListeners();
  }

  /// The previous location, or null at the start. The caller navigates to
  /// it; the matching [visit] is then recognised as travel.
  String? back() {
    if (!canGoBack) return null;
    _index--;
    _travelingTo = _entries[_index];
    notifyListeners();
    return _travelingTo;
  }

  String? forward() {
    if (!canGoForward) return null;
    _index++;
    _travelingTo = _entries[_index];
    notifyListeners();
    return _travelingTo;
  }
}

/// History plus the navigation it drives, shared with the toolbar and menus.
final class NavigationHistoryScope
    extends InheritedNotifier<NavigationHistory> {
  const NavigationHistoryScope({
    required NavigationHistory history,
    required this.onNavigate,
    required super.child,
    super.key,
  }) : super(notifier: history);

  final ValueChanged<String> onNavigate;

  static NavigationHistoryScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavigationHistoryScope>();

  bool get canGoBack => notifier!.canGoBack;
  bool get canGoForward => notifier!.canGoForward;

  void goBack() {
    final location = notifier!.back();
    if (location != null) onNavigate(location);
  }

  void goForward() {
    final location = notifier!.forward();
    if (location != null) onNavigate(location);
  }
}
