import 'package:flutter/widgets.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/ui/ui.dart';

const shellFixtureToday = LocalDate(2026, 10, 8);
const shellFixtureChoices = <EraComboItem<Object?>>[
  EraComboItem('shift', 'Shift'),
  EraComboItem('leave', 'Leave'),
];

/// Real library hosts sharing a pending aggregate, with observable commands.
/// Synthetic only: no service, asynchronous save or database.
final class ShellEditorFixture extends StatefulWidget {
  const ShellEditorFixture({
    required this.controller,
    this.enabled = true,
    super.key,
  });

  final EditorSessionController controller;
  final bool enabled;

  @override
  State<ShellEditorFixture> createState() => ShellEditorFixtureState();
}

final class ShellEditorFixtureState extends State<ShellEditorFixture> {
  final records = <String, Map<String, Object?>>{
    for (var i = 0; i < 30; i++)
      'row:$i': {
        'id': 'row:$i',
        'note': 'Note $i',
        'hours': '8',
        'day': shellFixtureToday,
        'kind': 'shift',
        'paid': true,
      },
  };
  final actionValues = <String, Object?>{'reason': 'Correction', 'paid': true};
  final events = <String>[];
  String selected = 'row:0';
  String treeSelection = 'shifts';
  String area = 'work';
  String tab = 'children';
  String? sortColumn;
  final picked = <String>{};

  Map<String, Object?> get values => records[selected]!;
  EditorSessionController get controller => widget.controller;

  EditResult commit(EditIdentity id, Object? value) {
    if ('$value'.trim().isEmpty) {
      events.add('reject:${id.record}:${id.field}');
      return const EditResult.rejected('Enter a value.');
    }
    final record = records[id.record];
    if (record == null) return const EditResult.rejected('Record removed.');
    events.add('commit:${id.record}:${id.field}');
    setState(() => record[id.field] = value);
    return const EditResult.accepted();
  }

  void command(String name, VoidCallback action) {
    if (!controller.flush().isAccepted) return;
    events.add(name);
    setState(action);
  }

  Future<void> confirm() async {
    final result = await showConfirmWindow<bool>(
      context,
      title: 'Discard draft?',
      message: 'Synthetic confirmation with an editor underneath.',
      choices: const [
        ConfirmChoice(value: true, label: 'Discard'),
        ConfirmChoice(value: false, label: 'Keep editing'),
      ],
      cancelValue: false,
    );
    events.add('confirm:$result');
  }

  List<PropertyItem> get properties => [
    for (final (name, kind) in const [
      ('note', ValueKind.text),
      ('hours', ValueKind.number),
      ('day', ValueKind.date),
      ('kind', ValueKind.choice),
      ('paid', ValueKind.check),
    ])
      PropertyItem(
        key: name,
        label: name,
        category: 'Record',
        kind: kind,
        value: values[name],
        choices: shellFixtureChoices,
        description: 'Synthetic $name field.',
      ),
  ];

  @override
  Widget build(BuildContext context) => EraFormScope(
    enabled: widget.enabled,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BandedToolbar(
          bands: [
            ToolbarBand(
              items: [
                ToolbarItem(
                  label: 'Save',
                  onPressed: widget.enabled
                      ? () => command('save', () {})
                      : null,
                ),
                ToolbarItem(
                  label: 'Undo',
                  onPressed: widget.enabled
                      ? () {
                          controller.cancel();
                          events.add('undo');
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
        TabStrip(
          tabs: [
            TabItem(id: 'work', label: 'Work', enabled: widget.enabled),
            TabItem(id: 'people', label: 'People', enabled: widget.enabled),
          ],
          selectedId: area,
          onSelect: (id) => command('area:$id', () => area = id),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 170,
                child: Column(
                  children: [
                    TreeView(
                      label: 'Objects',
                      nodes: const [
                        TreeNodeData(
                          id: 'root',
                          label: 'Employment',
                          expanded: true,
                          children: [
                            TreeNodeData(id: 'shifts', label: 'Shifts'),
                            TreeNodeData(id: 'periods', label: 'Pay periods'),
                          ],
                        ),
                      ],
                      selectedId: treeSelection,
                      onSelect: (id) =>
                          command('tree:$id', () => treeSelection = id),
                      enabled: widget.enabled,
                    ),
                    Expanded(
                      child: DetailsBox(
                        caption: 'Details',
                        sections: [
                          DetailsSection(
                            facts: [
                              DetailsFact(
                                'Agreement',
                                'Synthetic agreement',
                                onFollow: widget.enabled
                                    ? () => command('follow', () {})
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: DataGrid<Map<String, Object?>>(
                        key: const ValueKey('fixture-grid'),
                        label: 'Records',
                        columns: [
                          for (final (name, kind, width) in const [
                            ('note', ValueKind.text, 140.0),
                            ('hours', ValueKind.number, 80.0),
                            ('day', ValueKind.date, 140.0),
                            ('kind', ValueKind.choice, 100.0),
                            ('paid', ValueKind.check, 60.0),
                          ])
                            GridColumn<Map<String, Object?>>(
                              key: name,
                              label: name,
                              kind: kind,
                              width: width,
                              value: (row) => row[name],
                              choices: shellFixtureChoices,
                              editable: true,
                            ),
                        ],
                        lines: [for (final row in records.values) GridRow(row)],
                        rowId: (row) => row['id']! as String,
                        rowLabel: (row) => 'Record ${row['id']}',
                        selectedId: selected,
                        editorController: controller,
                        currentRow: (id) => records[id],
                        onSelect: (id) {
                          events.add('select:$id');
                          setState(() => selected = id);
                        },
                        onEdit: (cell, draft) => commit(cell.identity, draft),
                        today: shellFixtureToday,
                        sortColumn: sortColumn,
                        onSort: (id) {
                          events.add('sort:$id');
                          setState(() => sortColumn = id);
                        },
                        pickMode: true,
                        pickedIds: picked,
                        onPick: (id, value) {
                          events.add('pick:$id');
                          setState(
                            () => value ? picked.add(id) : picked.remove(id),
                          );
                        },
                        onNew: () => events.add('new'),
                      ),
                    ),
                    SizedBox(
                      height: 120,
                      child: Subform(
                        selectedId: tab,
                        controller: controller,
                        onSelect: (id) {
                          events.add('subform:$id');
                          setState(() => tab = id);
                        },
                        tabs: [
                          SubformTab(
                            id: 'children',
                            label: 'Children',
                            enabled: widget.enabled,
                            builder: (_) =>
                                const Text('Synthetic child records'),
                          ),
                          SubformTab(
                            id: 'history',
                            label: 'History',
                            enabled: widget.enabled,
                            builder: (_) => const Text('Synthetic history'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 306,
                child: PropertyGrid(
                  record: selected,
                  controller: controller,
                  items: properties,
                  onCommit: commit,
                  today: shellFixtureToday,
                  onOrderChanged: (order) => events.add('order:$order'),
                ),
              ),
              SizedBox(
                width: 280,
                child: ActionPanel(
                  title: 'Correct records',
                  record: 'action:fixture',
                  controller: controller,
                  groups: () => [
                    ActionGroup(
                      legend: 'Correction',
                      fields: [
                        ActionField(
                          id: 'reason',
                          label: 'Reason',
                          kind: ValueKind.text,
                          value: actionValues['reason'],
                          validate: (value) =>
                              '$value'.isEmpty ? 'Enter a reason.' : null,
                        ),
                        ActionField(
                          id: 'paid',
                          label: 'Paid',
                          kind: ValueKind.check,
                          value: actionValues['paid'],
                        ),
                      ],
                    ),
                  ],
                  onChanged: (field, value) {
                    events.add('action:$field');
                    setState(() => actionValues[field] = value);
                  },
                  primaryLabel: 'Correct',
                  onPrimary: () => events.add('primary'),
                  onCancel: () => events.add('cancel'),
                ),
              ),
            ],
          ),
        ),
        const StatusBar(
          notice: 'Synthetic fixture',
          panels: [StatusPanel('30 rows')],
        ),
      ],
    ),
  );
}
