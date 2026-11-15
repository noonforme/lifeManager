import 'work_location.dart';

/// The Back and Forward history of Work places (spec 4.5). A tree node, a
/// month or a followed link pushes a place and drops the places ahead; a
/// change of selected row or subform tab replaces the current one, so the
/// route stays exact without a Back step per clicked row. It never asks
/// anything: the shell moves it only once the current record let go.
final class WorkHistory {
  WorkHistory(WorkLocation start) : _places = [start];

  final List<WorkLocation> _places;
  int _index = 0;

  WorkLocation get current => _places[_index];
  bool get canBack => _index > 0;
  bool get canForward => _index < _places.length - 1;

  /// The place Back goes to; null at the start.
  WorkLocation? get previous => canBack ? _places[_index - 1] : null;

  /// The place Forward goes to; null at the end.
  WorkLocation? get next => canForward ? _places[_index + 1] : null;

  /// Goes to [place], dropping the places ahead. The current place again
  /// adds nothing.
  void push(WorkLocation place) {
    if (place == current) return;
    _places
      ..removeRange(_index + 1, _places.length)
      ..add(place);
    _index++;
  }

  /// Puts [place] in the current place's stead.
  void replace(WorkLocation place) => _places[_index] = place;

  /// Steps back to [previous], as it was resolved: [place] replaces it.
  void back(WorkLocation place) {
    assert(canBack);
    _index--;
    _places[_index] = place;
  }

  /// Steps forward to [next], as it was resolved: [place] replaces it.
  void forward(WorkLocation place) {
    assert(canForward);
    _index++;
    _places[_index] = place;
  }
}
