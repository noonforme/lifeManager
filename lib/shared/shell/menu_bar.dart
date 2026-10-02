import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../workbench/cell_selection.dart';
import '../workbench/era_dialog.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/office_controls.dart';
import 'navigation_history.dart';
import 'shell_frame.dart';

/// The shell's menu bar (spec 5.3). Items whose feature has not shipped
/// stay visible, disabled, with the reason as a tooltip.
final class LifeOSMenuBar extends StatelessWidget {
  const LifeOSMenuBar({required this.onNavigate, this.onQuit, super.key});

  final ValueChanged<String> onNavigate;

  /// Closes the window. Null disables Quit (for example in tests).
  final VoidCallback? onQuit;

  static const _desks = "Open Today and use the desk's own Desk menu";
  static const _history = 'Open a record and choose its History tab';

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final view = ShellViewScope.maybeOf(context);
    final history = NavigationHistoryScope.maybeOf(context);
    final cell = CellSelectionScope.maybeOf(context)?.value;
    final quickAdd = ShellChrome.maybeOf(context)?.quickAdd ?? const [];
    final explanation = cell?.explanation;
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(tokens.paper),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      side: WidgetStatePropertyAll(BorderSide(color: tokens.muted)),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 2)),
    );
    final itemStyle = ButtonStyle(
      textStyle: WidgetStatePropertyAll(skin.typography.body),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? tokens.muted
            : states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
            ? tokens.selInk
            : tokens.ink,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)
            ? tokens.selWash
            : Colors.transparent,
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, menuRowHeight)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8),
      ),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
    );

    Widget item(String label, VoidCallback? onPressed) => MenuItemButton(
      style: itemStyle,
      onPressed: onPressed,
      child: Text(label),
    );

    Widget later(String label, String reason) => MenuItemButton(
      style: itemStyle,
      onPressed: null,
      child: Tooltip(message: reason, child: Text(label)),
    );

    Widget menu(String label, List<Widget> children) => SubmenuButton(
      style: itemStyle,
      menuStyle: menuStyle,
      menuChildren: children,
      child: Text(label),
    );

    Widget viewItem(
      String label,
      bool Function(ShellView) read,
      ShellView Function(ShellView, bool) write,
    ) {
      final current = view?.value ?? const ShellView();
      return CheckboxMenuButton(
        style: itemStyle,
        value: read(current),
        onChanged: view == null
            ? null
            : (checked) => view.value = write(view.value, checked ?? false),
        child: Text(label),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.paper, tokens.chrome],
        ),
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ExcludeSemantics(
              child: Text(
                'LifeOS',
                style: skin.typography.body.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: MenuBar(
              style: MenuStyle(
                backgroundColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                elevation: const WidgetStatePropertyAll(0),
                shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                surfaceTintColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              ),
              children: [
                menu('File', [
                  item('Backup and export…', () => onNavigate('/system/files')),
                  item('Quit', onQuit),
                ]),
                menu('Edit', [
                  item(
                    'Copy cell',
                    cell == null
                        ? null
                        : () => Clipboard.setData(
                            ClipboardData(text: cell.display),
                          ),
                  ),
                  later('Copy row', 'Copy row arrives in a later update'),
                  item(
                    'Copy explanation',
                    explanation == null
                        ? null
                        : () => Clipboard.setData(
                            ClipboardData(text: explanation.plainText),
                          ),
                  ),
                ]),
                menu('View', [
                  viewItem(
                    'Show task pane',
                    (v) => v.showTree,
                    (v, on) => v.copyWith(showTree: on),
                  ),
                  viewItem(
                    'Show property sheet',
                    (v) => v.showInspector,
                    (v, on) => v.copyWith(showInspector: on),
                  ),
                ]),
                menu('Desk', [
                  item('Open Today', () => onNavigate('/today')),
                  later('New desk', _desks),
                  later('Add sheet to desk', _desks),
                  later('Layout', _desks),
                  later('Rename desk', _desks),
                  later('Reset starter desk', _desks),
                ]),
                menu('Record', [
                  for (final entry in quickAdd)
                    item('+ ${entry.label}', entry.open),
                  later('Show history', _history),
                ]),
                menu('Window', [
                  item(
                    'Back',
                    history != null && history.canGoBack
                        ? history.goBack
                        : null,
                  ),
                  item(
                    'Forward',
                    history != null && history.canGoForward
                        ? history.goForward
                        : null,
                  ),
                  item('Today', () => onNavigate('/today')),
                  item('Journal', () => onNavigate('/journal')),
                ]),
                menu('Help', [
                  item(
                    'About LifeOS',
                    () => showDialog<void>(
                      context: context,
                      builder: (context) => EraDialog(
                        title: 'About LifeOS',
                        body: const Text(
                          'LifeOS\nPrivate, local-first records. Nothing leaves this computer.',
                        ),
                        actions: [
                          KeyButton(
                            label: 'Licenses',
                            onPressed: () => showLicensePage(
                              context: context,
                              applicationName: 'LifeOS',
                            ),
                          ),
                          KeyButton(
                            label: 'OK',
                            kind: KeyKind.primary,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
