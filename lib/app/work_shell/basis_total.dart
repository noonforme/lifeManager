import '../../features/work/domain/facts.dart';
import '../../features/work/domain/pay.dart';
import '../../features/work/domain/work_formats.dart';
import 'pay_sheet_part.dart' show payBasis;

/// Amounts added up per basis: gross and net are never combined
/// (foundation spec 9.5, bead 9pk.4.35). An amount without a basis adds
/// nothing.
final class BasisTotal {
  BasisTotal(Iterable<(Money?, RateBasis?)> amounts) {
    for (final (money, basis) in amounts) {
      if (money == null || basis == null) continue;
      _cents[basis] = (_cents[basis] ?? 0) + money.minorUnits;
    }
  }

  /// From cents per basis, as the schedule Preview prices them.
  BasisTotal.cents(Map<RateBasis, int> cents)
    : this([
        for (final MapEntry(key: basis, value: minor) in cents.entries)
          (Money(minorUnits: minor), basis),
      ]);

  final _cents = <RateBasis, int>{};

  /// Gross and net amounts are both present.
  bool get mixed => _cents.length > 1;

  /// Gross first, then net.
  List<(RateBasis, Money)> get _subtotals => [
    for (final basis in const [GrossBasis(), NetBasis()])
      if (_cents[basis] case final cents?) (basis, Money(minorUnits: cents)),
  ];

  /// A total cell: the one amount, or "Mixed basis".
  String get cell => mixed
      ? payBasis(null)
      : formatMoney(Money(minorUnits: _cents.values.firstOrNull ?? 0));

  /// What follows a total's label when mixed, " · Gross EUR 147.20 · Net
  /// EUR 80.00"; empty otherwise.
  String get labelSuffix => mixed
      ? [
          for (final (basis, money) in _subtotals)
            ' · ${payBasis(basis)} ${formatMoney(money)}',
        ].join()
      : '';

  /// In a sentence: "EUR 147.20", or "EUR 147.20 gross and EUR 80.00 net".
  String get words => mixed
      ? [
          for (final (basis, money) in _subtotals)
            '${formatMoney(money)} ${payBasis(basis).toLowerCase()}',
        ].join(' and ')
      : cell;
}
