import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

/// Subform tabs over a bordered region: child editors and a Properties tab.
final subformDemo = GalleryDemo(
  id: 'data/subform',
  widget: 'Subform',
  summary:
      'A record\'s children: subform tabs (20/22 px) over a bordered region. '
      'The Shifts tab holds editors and the Properties tab an editor of the '
      'record; one editor session is shared, so a tab change first accepts '
      'the open draft. Type "x" into Hours and try another tab: the change is '
      'refused and the draft stays red. Content stays alive when a tab '
      'hides. The Enabled knob disables the History tab; Error shows a '
      'caller error.',
  size: const Size(520, 280),
  build: (context, knobs) => _SubformDemo(knobs: knobs),
);

final class _SubformDemo extends StatefulWidget {
  const _SubformDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_SubformDemo> createState() => _SubformDemoState();
}

final class _SubformDemoState extends State<_SubformDemo> {
  final _controller = EditorSessionController();
  final Map<String, Object?> _values = {'hours': 8, 'note': 'Late shift'};
  String _selected = 'shifts';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  EditResult _commit(EditIdentity id, Object? draft) {
    Object? value = draft;
    if (id.field == 'hours') {
      value = int.tryParse('$draft');
      if (value == null) {
        return const EditResult.rejected('Enter whole hours.');
      }
    }
    setState(() => _values[id.field] = value);
    return const EditResult.accepted();
  }

  EditField _field(String name, ValueKind kind) => EditField(
    id: EditIdentity(record: 'shift:demo', field: name),
    kind: kind,
    value: _values[name],
    commit: _commit,
  );

  Widget _editor(String name, ValueKind kind, String label, String? error) =>
      CellEditor(
        controller: _controller,
        field: _field(name, kind),
        label: label,
        bare: false,
        error: error,
      );

  @override
  Widget build(BuildContext context) {
    final knobs = widget.knobs;
    final scale = MediaQuery.textScalerOf(context);
    return SizedBox(
      width: scale.scale(480),
      height: scale.scale(220),
      child: Subform(
        label: 'Shift details',
        controller: _controller,
        selectedId: _selected,
        onSelect: (id) => setState(() => _selected = id),
        trailing: Text(
          knobs.text('2 rows', '2 rows, 1 waiting to be confirmed'),
        ),
        tabs: [
          SubformTab(
            id: 'shifts',
            label: knobs.text('Shifts', 'Shifts of this pay agreement period'),
            icon: EraIconKind.agreement,
            count: 2,
            countLabel: 'rows',
            builder: (context) => Padding(
              padding: const EdgeInsets.all(8),
              child: _editor(
                'hours',
                ValueKind.number,
                'Hours',
                knobs.errorText,
              ),
            ),
          ),
          SubformTab(
            id: 'history',
            label: 'History',
            enabled: knobs.enabled,
            disabledReason: 'Switched off in this demo.',
            builder: (context) => const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No history yet.'),
            ),
          ),
          SubformTab(
            id: 'properties',
            label: 'Properties',
            icon: EraIconKind.properties,
            builder: (context) => Padding(
              padding: const EdgeInsets.all(8),
              child: _editor('note', ValueKind.text, 'Note', null),
            ),
          ),
        ],
      ),
    );
  }
}
