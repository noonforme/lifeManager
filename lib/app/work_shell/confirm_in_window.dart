import 'package:flutter/widgets.dart';

import '../../ui/ui.dart';
import '../edit_session/confirm.dart';

/// Asks [request] in the era confirmation window (spec 4.7): the
/// affirmative key first, then the key that drops the pending values, then
/// the key that stays, which the window's close key answers too.
Future<ConfirmAnswer> confirmInWindow(
  BuildContext context,
  ConfirmRequest request,
) => showConfirmWindow<ConfirmAnswer>(
  context,
  title: request.title,
  message: request.message,
  choices: [
    if (request.proceed case final label?)
      ConfirmChoice(value: ConfirmAnswer.proceed, label: label),
    if (request.revert case final label?)
      ConfirmChoice(value: ConfirmAnswer.revert, label: label),
    ConfirmChoice(value: ConfirmAnswer.cancel, label: request.cancel),
  ],
  cancelValue: ConfirmAnswer.cancel,
  sign: request.warning ? ConfirmSign.warning : ConfirmSign.info,
);
