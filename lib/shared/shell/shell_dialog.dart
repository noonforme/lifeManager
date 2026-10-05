import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../workbench/era_controls.dart';
import '../workbench/era_dialog.dart';
import '../workbench/era_icons.dart';
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
    this.fitHeight = false,
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;
  final ShellDialogKind kind;

  /// The dialog's size; it shrinks to 90 % of a smaller window. With
  /// [fitHeight], the height is a maximum and the dialog fits its content.
  final Size size;

  /// Sizes the dialog to its content, for a message or a one-key step.
  final bool fitHeight;
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
/// is open, so its scroll positions, selection and drafts survive. When the
/// dialog closes, keyboard focus goes back to where it was, so Enter,
/// Escape and the arrow keys carry on in the list.
final class ShellDialogLayer extends StatefulWidget {
  const ShellDialogLayer({
    required this.dialog,
    required this.child,
    super.key,
  });

  final ShellDialog? dialog;
  final Widget child;

  @override
  State<ShellDialogLayer> createState() => _ShellDialogLayerState();
}

final class _ShellDialogLayerState extends State<ShellDialogLayer> {
  FocusNode? _returnTo;

  @override
  void didUpdateWidget(covariant ShellDialogLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final opened = oldWidget.dialog == null && widget.dialog != null;
    final closed = oldWidget.dialog != null && widget.dialog == null;
    if (opened) _returnTo = FocusManager.instance.primaryFocus;
    if (closed) {
      final node = _returnTo;
      _returnTo = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && node != null && node.context != null) {
          node.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialog = widget.dialog;
    final open = dialog != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: open,
          child: AbsorbPointer(
            absorbing: open,
            child: ExcludeSemantics(excluding: open, child: widget.child),
          ),
        ),
        if (dialog != null)
          LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                key: const ValueKey('shell-dialog'),
                constraints: BoxConstraints(
                  minWidth: math.min(
                    dialog.size.width,
                    constraints.maxWidth * 0.9,
                  ),
                  maxWidth: math.min(
                    dialog.size.width,
                    constraints.maxWidth * 0.9,
                  ),
                  minHeight: dialog.fitHeight
                      ? 0
                      : math.min(
                          dialog.size.height,
                          constraints.maxHeight * 0.9,
                        ),
                  maxHeight: math.min(
                    dialog.size.height,
                    constraints.maxHeight * 0.9,
                  ),
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
        // A form's own autofocus field takes focus; otherwise the scope does.
        autofocus: dialog.kind == ShellDialogKind.form,
        // On a sheet or message box the dialog itself holds focus when it opens. There, Enter is the
        // Properties sheet's default key, OK, as in the era; on a focused
        // key, Enter presses that key instead.
        child: Focus(
          autofocus: dialog.kind != ShellDialogKind.form,
          onKeyEvent: (node, event) {
            final enter =
                event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter);
            if (enter &&
                dialog.kind != ShellDialogKind.form &&
                FocusManager.instance.primaryFocus == node) {
              dialog.onClose();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
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
                mainAxisSize: dialog.fitHeight
                    ? MainAxisSize.min
                    : MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CaptionBar(
                    title: dialog.title,
                    large: true,
                    onClose: dialog.onClose,
                  ),
                  Flexible(
                    fit: dialog.fitHeight ? FlexFit.loose : FlexFit.tight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ShellDialogScope(
                        onClose: dialog.onClose,
                        child: DefaultTextStyle.merge(
                          style: skin.typography.body.copyWith(
                            color: tokens.ink,
                          ),
                          // A message box leads with the era's warning sign.
                          child: dialog.kind == ShellDialogKind.message
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: EraIcon(
                                        EraIconKind.warning,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: dialog.child),
                                  ],
                                )
                              : dialog.child,
                        ),
                      ),
                    ),
                  ),
                  if (dialog.kind == ShellDialogKind.message)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: FormFooter(
                        children: [
                          KeyButton(
                            label: 'OK',
                            kind: KeyKind.primary,
                            onPressed: dialog.onClose,
                          ),
                        ],
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
      ),
    );
  }
}
