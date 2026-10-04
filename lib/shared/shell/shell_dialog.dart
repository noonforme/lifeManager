import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../workbench/era_controls.dart';
import '../workbench/era_dialog.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';
import '../workbench/office_controls.dart';

/// What a dialog is for (XP-authentic shell spec 4): a record's Properties
/// sheet, which gets **OK** and **Cancel** at its foot; a form, which keeps
/// its own keys; or a message box.
enum ShellDialogKind { properties, form, message }

/// A dialog the shell paints over the whole window. Whether it is open
/// lives in the route, so Back and Forward close and reopen it.
@immutable
final class ShellDialog {
  const ShellDialog({
    required this.title,
    required this.child,
    required this.onClose,
    this.kind = ShellDialogKind.form,
    this.size = const Size(440, 560),
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;
  final ShellDialogKind kind;

  /// The dialog's size; it shrinks to 90 % of a smaller window.
  final Size size;
}

/// Lets a key inside a dialog close it.
final class ShellDialogScope extends InheritedWidget {
  const ShellDialogScope({
    required this.onClose,
    required super.child,
    super.key,
  });

  final VoidCallback onClose;

  static VoidCallback? closeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellDialogScope>()?.onClose;

  @override
  bool updateShouldNotify(ShellDialogScope oldWidget) =>
      onClose != oldWidget.onClose;
}

/// **Cancel** at the end of a form's footer. Outside a dialog it is absent.
final class DialogCancelKey extends StatelessWidget {
  const DialogCancelKey({super.key});

  @override
  Widget build(BuildContext context) {
    final close = ShellDialogScope.closeOf(context);
    if (close == null) return const SizedBox.shrink();
    return KeyButton(label: 'Cancel', onPressed: close);
  }
}

/// The window, with [dialog] over it when one is open. The window keeps its
/// look but takes no input or focus while the dialog is up, as an era modal
/// dialog did. The window's subtree keeps one shape whether or not a dialog
/// is open, so its scroll positions, selection and drafts survive.
final class ShellDialogLayer extends StatelessWidget {
  const ShellDialogLayer({
    required this.dialog,
    required this.child,
    super.key,
  });

  final ShellDialog? dialog;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dialog = this.dialog;
    final open = dialog != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: open,
          child: AbsorbPointer(
            absorbing: open,
            child: ExcludeSemantics(excluding: open, child: child),
          ),
        ),
        if (dialog != null)
          LayoutBuilder(
            builder: (context, constraints) => Center(
              child: SizedBox(
                key: const ValueKey('shell-dialog'),
                width: math.min(dialog.size.width, constraints.maxWidth * 0.9),
                height: math.min(
                  dialog.size.height,
                  constraints.maxHeight * 0.9,
                ),
                child: _DialogWindow(dialog: dialog),
              ),
            ),
          ),
      ],
    );
  }
}

final class _DialogWindow extends StatelessWidget {
  const _DialogWindow({required this.dialog});

  final ShellDialog dialog;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): dialog.onClose,
      },
      child: FocusScope(
        autofocus: true,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: dialog.title,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: tokens.chrome,
              border: Border.all(color: MillenniumColors.keyLine),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CaptionBar(title: dialog.title, onClose: dialog.onClose),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ShellDialogScope(
                      onClose: dialog.onClose,
                      child: DefaultTextStyle.merge(
                        style: skin.typography.body.copyWith(color: tokens.ink),
                        child: dialog.child,
                      ),
                    ),
                  ),
                ),
                if (dialog.kind == ShellDialogKind.properties)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: FormFooter(
                      children: [
                        KeyButton(
                          label: 'OK',
                          kind: KeyKind.primary,
                          onPressed: dialog.onClose,
                        ),
                        KeyButton(label: 'Cancel', onPressed: dialog.onClose),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
