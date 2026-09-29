final class LocalTime {
  const LocalTime(this.hour, this.minute, [this.second = 0])
    : assert(hour >= 0 && hour <= 23),
      assert(minute >= 0 && minute <= 59),
      assert(second >= 0 && second <= 59);

  final int hour;
  final int minute;
  final int second;

  @override
  bool operator ==(Object other) =>
      other is LocalTime &&
      hour == other.hour &&
      minute == other.minute &&
      second == other.second;

  @override
  int get hashCode => Object.hash(hour, minute, second);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:'
      '${second.toString().padLeft(2, '0')}';
}
