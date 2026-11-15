import 'package:flutter/foundation.dart';

import 'shifts_lines.dart';

/// The Status filter of the Shifts sheet (spec 3): which rows it keeps.
enum ShiftsStatusFilter {
  all('All', null),
  effective('Effective', 'effective'),
  planned('Planned', 'planned'),
  toConfirm('To confirm', 'toconfirm'),
  review('Needs review', 'review'),
  draft('Draft', 'draft'),
  finalized('Finalized', 'finalized'),
  voided('Void', 'void');

  const ShiftsStatusFilter(this.label, this.routeWord);

  final String label;

  /// Its word in the route's `status=`; null for All (none).
  final String? routeWord;

  /// The filter a route's `status=` names; All when it names none.
  static ShiftsStatusFilter fromRoute(String? word) =>
      values.where((value) => value.routeWord == word).firstOrNull ?? all;

  /// Whether a row of [status] passes; [toConfirm] says it waits to be
  /// confirmed. A cancelled day shows under All only.
  bool admits(ShiftsStatus status, {bool toConfirm = false}) => switch (this) {
    all => true,
    effective =>
      status != ShiftsStatus.voided && status != ShiftsStatus.cancelled,
    planned =>
      status == ShiftsStatus.planned ||
          status == ShiftsStatus.changed ||
          status == ShiftsStatus.extra ||
          status == ShiftsStatus.leave,
    ShiftsStatusFilter.toConfirm => toConfirm,
    review => status == ShiftsStatus.review,
    draft => status == ShiftsStatus.draft,
    finalized => status == ShiftsStatus.finalized,
    voided => status == ShiftsStatus.voided,
  };
}

/// The Shifts sheet's filters as the route carries them (spec 4.5): a
/// status, a shift type (null for All; `Extra` and `Manual` are types of
/// their own) and whether Off days are listed.
@immutable
final class ShiftsFilter {
  const ShiftsFilter({
    this.status = ShiftsStatusFilter.all,
    this.type,
    this.offDays = false,
  });

  /// Every row, no Off days: the sheet as it opens.
  static const none = ShiftsFilter();

  final ShiftsStatusFilter status;
  final String? type;
  final bool offDays;

  bool get isNone => this == none;

  ShiftsFilter copyWith({
    ShiftsStatusFilter? status,
    String? Function()? type,
    bool? offDays,
  }) => ShiftsFilter(
    status: status ?? this.status,
    type: type == null ? this.type : type(),
    offDays: offDays ?? this.offDays,
  );

  @override
  bool operator ==(Object other) =>
      other is ShiftsFilter &&
      other.status == status &&
      other.type == type &&
      other.offDays == offDays;

  @override
  int get hashCode => Object.hash(status, type, offDays);
}
