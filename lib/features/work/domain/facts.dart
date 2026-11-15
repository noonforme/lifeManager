sealed class RateBasis {
  const RateBasis();
}

final class GrossBasis extends RateBasis {
  const GrossBasis();

  @override
  bool operator ==(Object other) => other is GrossBasis;

  @override
  int get hashCode => 1;
}

final class NetBasis extends RateBasis {
  const NetBasis();

  @override
  bool operator ==(Object other) => other is NetBasis;

  @override
  int get hashCode => 2;
}

final class CurrencyCode {
  const CurrencyCode.eur() : value = 'EUR';

  final String value;

  @override
  bool operator ==(Object other) =>
      other is CurrencyCode && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

final class Revision {
  const Revision(this.value) : assert(value >= 0);

  factory Revision.checked(int value) {
    if (value < 0) throw ArgumentError.value(value, 'value');
    return Revision(value);
  }

  final int value;

  Revision next() => Revision(value + 1);

  @override
  bool operator ==(Object other) => other is Revision && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

final class DomainIssue {
  const DomainIssue(this.code, {this.field});

  final String code;
  final String? field;

  @override
  bool operator ==(Object other) =>
      other is DomainIssue && code == other.code && field == other.field;

  @override
  int get hashCode => Object.hash(code, field);
}

final class DomainValidation {
  const DomainValidation(this.issues);

  final List<DomainIssue> issues;

  bool get isValid => issues.isEmpty;
}
