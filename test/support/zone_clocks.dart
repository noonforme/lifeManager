import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/core/time/wall_clock.dart';

/// Real IANA wall clocks, as production reads them.
final testZoneClocks = zoneClocksOf(IanaTimezoneService());
