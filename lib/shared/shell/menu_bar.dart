import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/ui.dart';
import 'licenses_dialog.dart';
import 'navigation_history.dart';
import 'shell_frame.dart';
import 'status_line.dart';

/// The shell's menu bar (spec 5.3). Items whose feature has not shipped
/// stay visible, disabled, with the reason as a tooltip.
final class LifeOSMenuBar extends StatelessWidget {
  const LifeOSMenuBar({required this.onNavigate, this.onQuit, super.key});

  final ValueChanged<String> onNavigate;

  /// Closes the window. Null disables Quit (for example in tests).
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final view = ShellViewScope.maybeOf(context);
    final history = NavigationHistoryScope.maybeOf(context);
    final cell = CellSelectionScope.maybeOf(context)?.value;
    final quickAdd = ShellChrome.maybeOf(context)?.quickAdd ?? const [];
    final explanation = cell?.explanation;
    final menuStyle = eraMenuStyle(skin);
    final itemStyle = eraMenuItemStyle(skin);
    // Titles on the bar keep a plain 8 px inset; drop-down rows have the
    // gutter.
    final barStyle = eraMenuItemStyle(
      skin,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );

    final hints = StatusHintScope.read(context);
    // A lit row says what it does in the status bar, as the era's did.
    void hint(String? text) => hints?.value = text;

    Widget item(
      String label,
      VoidCallback? onPressed, {
      required String hint,
      EraIconKind? icon,
    }) => MenuItemButton(
      style: itemStyle,
      onPressed: onPressed,
      onHover: (lit) => lit ? hints?.value = hint : null,
      onFocusChange: (lit) => lit ? hints?.value = hint : null,
      child: EraMenuLabel(EraMenuItem(label, onPressed, icon: icon)),
    );

    // [label] marks its Alt letter with "&", as "&File".
    Widget menu(String label, List<Widget> children) => SubmenuButton(
      style: barStyle,
      menuStyle: menuStyle,
      menuChildren: children,
      onClose: () => hint(null),
      child: MenuAcceleratorLabel(label),
    );

    Widget viewItem(
      String label,
      bool Function(ShellView) read,
      ShellView Function(ShellView, bool) write,
    ) {
      final current = view?.value ?? const ShellView();
      final onPressed = view == null
          ? null
          : () => view.value = write(view.value, !read(view.value));
      const text = 'Shows or hides the task pane.';
      return MenuItemButton(
        style: itemStyle,
        onPressed: onPressed,
        onHover: (lit) => lit ? hint(text) : null,
        onFocusChange: (lit) => lit ? hint(text) : null,
        child: EraMenuLabel(
          EraMenuItem(label, onPressed, checked: read(current)),
        ),
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
                menu('&File', [
                  item(
                    'Backup and export…',
                    () => onNavigate('/system/files'),
                    hint: 'Saves a copy of your records to a file you choose.',
                  ),
                  item('Quit', onQuit, hint: 'Closes LifeOS.'),
                ]),
                menu('&Edit', [
                  item(
                    'Copy cell',
                    cell == null
                        ? null
                        : () => Clipboard.setData(
                            ClipboardData(text: cell.display),
                          ),
                    hint: "Copies the selected cell's value.",
                  ),
                  item(
                    'Copy explanation',
                    explanation == null
                        ? null
                        : () => Clipboard.setData(
                            ClipboardData(text: explanation.plainText),
                          ),
                    hint: 'Copies how the selected figure was worked out.',
                  ),
                ]),
                menu('&View', [
                  viewItem(
                    'Show task pane',
                    (v) => v.showTaskPane,
                    (v, on) => v.copyWith(showTaskPane: on),
                  ),
                ]),
                menu('&Desk', [
                  item(
                    'Open Today',
                    () => onNavigate('/today'),
                    hint: 'Opens the Today desk.',
                  ),
                ]),
                menu('&Record', [
                  for (final entry in quickAdd)
                    item(
                      entry.label,
                      entry.open,
                      icon: entry.shownIcon,
                      hint: 'Adds a new ${entry.label.toLowerCase()}.',
                    ),
                ]),
                menu('&Window', [
                  item(
                    'Back',
                    history != null && history.canGoBack
                        ? history.goBack
                        : null,
                    hint: 'Goes back to the last place.',
                  ),
                  item(
                    'Forward',
                    history != null && history.canGoForward
                        ? history.goForward
                        : null,
                    hint: 'Goes forward again.',
                  ),
                  item(
                    'Today',
                    () => onNavigate('/today'),
                    hint: 'Opens the Today desk.',
                  ),
                  item(
                    'Journal',
                    () => onNavigate('/journal'),
                    hint: 'Opens every record by the time it happened.',
                  ),
                ]),
                menu('&Help', [
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
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => const LicensesDialog(),
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
                    hint: 'Shows the version and licences.',
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
