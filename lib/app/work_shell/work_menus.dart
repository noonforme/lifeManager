import 'package:flutter/foundation.dart';

import '../../ui/ui.dart';
import 'work_location.dart';
import 'work_shell.dart' show WorkShellWords;
import 'work_tree.dart';

/// Why a menu row of the Work shell is greyed.
abstract final class WorkMenuWords {
  static const selectEmployment = 'Select an employment first.';
  static const noOptions = 'LifeOS has no options yet.';
  static const noRecord = 'No record is open.';
  static const treeShown = 'The tree is already shown.';
  static const onLicences = 'Return to the sheet first.';
}

/// The Work shell's menu bar (spec 3): File, Edit, View, Record, Tools,
/// Window, Help. [edit] and [record] come from the sheet shown; [onSheet]
/// opens one of [place]'s employment's sheets by its tree key; [onTree]
/// is null while the tree is not folded, or [treeBlocked] says why.
List<AppMenu> workMenus({
  required WorkLocation place,
  required VoidCallback? onNewEmployment,
  String? newEmploymentBlocked,
  required VoidCallback? onQuit,
  required List<EraMenuItem> edit,
  required VoidCallback? onBack,
  required VoidCallback? onForward,
  required void Function(String key) onSheet,
  required List<EraMenuItem> record,
  required VoidCallback? onTree,
  String? treeBlocked,
  required VoidCallback onRestorePanes,
  required VoidCallback onLicences,
}) => [
  AppMenu('File', [
    EraMenuItem(
      WorkShellWords.newEmployment,
      onNewEmployment,
      disabledReason: onNewEmployment == null ? newEmploymentBlocked : null,
    ),
    const EraMenuItem.separator(),
    EraMenuItem(WorkShellWords.quit, onQuit),
  ]),
  AppMenu('Edit', [
    if (edit.isEmpty) ...const [
      EraMenuItem('Save', null, disabledReason: WorkMenuWords.noRecord),
      EraMenuItem('Undo', null, disabledReason: WorkMenuWords.noRecord),
    ] else
      ...edit,
  ]),
  AppMenu('View', [
    EraMenuItem(WorkShellWords.back, onBack),
    EraMenuItem(WorkShellWords.forward, onForward),
    const EraMenuItem.separator(),
    for (final (key, label, icon, kind) in employmentSheets)
      place.employmentId == null
          ? EraMenuItem(
              label,
              null,
              icon: icon,
              disabledReason: WorkMenuWords.selectEmployment,
            )
          : EraMenuItem(
              label,
              () => onSheet(key),
              icon: icon,
              checked: place.sheet == kind,
            ),
  ]),
  AppMenu('Record', record),
  const AppMenu('Tools', [
    EraMenuItem('Options…', null, disabledReason: WorkMenuWords.noOptions),
  ]),
  AppMenu('Window', [
    EraMenuItem(
      'Tree',
      onTree,
      disabledReason: onTree == null
          ? treeBlocked ?? WorkMenuWords.treeShown
          : null,
    ),
    EraMenuItem('Restore pane sizes', onRestorePanes),
  ]),
  AppMenu('Help', [EraMenuItem('Licences', onLicences)]),
];

/// The Add menu (spec 3): Employment… always, then the record kinds the
/// sheet shown can create; Manual shift greyed with [manualShiftBlocked]
/// where the sheet adds none (archived, or To confirm).
List<EraMenuItem> workAddItems({
  required VoidCallback? onEmployment,
  String? employmentBlocked,
  VoidCallback? onManualShift,
  String? manualShiftBlocked,
  List<EraMenuItem> sheetItems = const [],
}) => [
  EraMenuItem(
    'Employment…',
    onEmployment,
    icon: EraIconKind.employment,
    disabledReason: onEmployment == null ? employmentBlocked : null,
  ),
  if (onManualShift != null || manualShiftBlocked != null)
    EraMenuItem(
      'Manual shift',
      onManualShift,
      icon: EraIconKind.shift,
      disabledReason: onManualShift == null ? manualShiftBlocked : null,
    ),
  ...sheetItems,
];
