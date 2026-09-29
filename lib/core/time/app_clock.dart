abstract interface class AppClock {
  DateTime nowUtc();
}

final class SystemAppClock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
