import 'package:flutter/widgets.dart';

import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../ui.dart';
import '../gallery_demo.dart';

final controlDemos = <GalleryDemo>[
  GalleryDemo(
    id: 'controls/orb',
    widget: 'Orb',
    summary:
        'The glossy toolbar orb: green Back and Forward, orange Add, grey '
        'when unavailable.',
    build: (context, knobs) => Wrap(
      spacing: 8,
      children: [
        Orb(
          glyph: OrbGlyph.back,
          tone: knobs.enabled ? OrbTone.green : OrbTone.grey,
        ),
        Orb(
          glyph: OrbGlyph.forward,
          tone: knobs.enabled ? OrbTone.green : OrbTone.grey,
        ),
        Orb(
          glyph: OrbGlyph.add,
          tone: knobs.enabled ? OrbTone.orange : OrbTone.grey,
        ),
      ],
    ),
  ),
  GalleryDemo(
    id: 'controls/era_combo_face',
    widget: 'EraComboFace',
    summary: 'A closed combo box: a white field beside the blue drop arrow.',
    build: (context, knobs) => EraComboFace(
      value: knobs.text('Shifts', 'Shifts and planned days for October 2026'),
    ),
  ),
  GalleryDemo(
    id: 'controls/combo_arrow',
    widget: 'ComboArrow',
    summary: 'The blue drop-arrow button at the right of a combo box.',
    build: (context, knobs) =>
        const SizedBox(width: 17, height: 21, child: ComboArrow()),
  ),
  GalleryDemo(
    id: 'controls/group_box',
    widget: 'GroupBox',
    summary: 'A titled frame around related fields, its legend in Head blue.',
    build: (context, knobs) => SizedBox(
      width: 300,
      child: GroupBox(
        legend: knobs.text('Rate', 'Rate, premiums and leave terms'),
        child: const Text('Hourly rate: EUR 18.40'),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/form_footer',
    widget: 'FormFooter',
    summary: "A form's keys, right-aligned, the affirmative key first.",
    build: (context, knobs) => SizedBox(
      width: 360,
      child: FormFooter(
        children: [
          KeyButton(
            label: knobs.text('Save', 'Save and reprice confirmed days'),
            kind: KeyKind.primary,
            onPressed: knobs.press(() {}),
          ),
          KeyButton(label: 'Cancel', onPressed: knobs.press(() {})),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_glyph',
    widget: 'EraGlyph',
    summary:
        'Painted marks: drop, sort and step arrows, collapse chevrons and a '
        'tick.',
    build: (context, knobs) => Wrap(
      spacing: 12,
      children: [
        for (final kind in EraGlyphKind.values)
          EraGlyph(
            kind,
            color: LifeOSSkinScope.of(context).tokens.ink,
            size: 12,
          ),
      ],
    ),
  ),
  GalleryDemo(
    id: 'controls/era_pressable',
    widget: 'EraPressable',
    summary:
        'A small pressable link or button with the dotted focus rectangle.'
        ' No disabled state, so the Enabled knob does not apply.',
    build: (context, knobs) => EraPressable(
      label: 'Confirm this day',
      link: true,
      onPressed: () {},
      child: Text(
        knobs.text(
          'Confirm this day…',
          'Confirm this day and every earlier unconfirmed day…',
        ),
        style: const TextStyle(color: MillenniumColors.link),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/key_button',
    widget: 'KeyButton',
    summary:
        'The era push key: primary (default ring), secondary, small and the '
        'flat toolbar kind.',
    build: (context, knobs) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in KeyKind.values)
          KeyButton(
            label: switch (kind) {
              KeyKind.primary => knobs.text('OK', 'Save agreement'),
              KeyKind.secondary => 'Cancel',
              KeyKind.small => 'Change…',
              KeyKind.toolbar => 'Back',
            },
            kind: kind,
            onPressed: knobs.press(() {}),
          ),
      ],
    ),
  ),
  GalleryDemo(
    id: 'controls/step_key',
    widget: 'StepKey',
    summary: 'Small keys with painted step arrows, for periods and days.',
    build: (context, knobs) => Wrap(
      spacing: 4,
      children: [
        StepKey(
          forward: false,
          semanticLabel: 'Previous month',
          onPressed: knobs.press(() {}),
        ),
        StepKey(
          forward: true,
          semanticLabel: 'Next month',
          onPressed: knobs.press(() {}),
        ),
      ],
    ),
  ),
  GalleryDemo(
    id: 'controls/area_key',
    widget: 'AreaKey',
    summary: "The painted icon that marks a record's area.",
    build: (context, knobs) => Wrap(
      spacing: 8,
      children: [for (final area in LifeOSArea.values) AreaKey(area: area)],
    ),
  ),
  GalleryDemo(
    id: 'controls/count_badge',
    widget: 'CountBadge',
    summary: 'An orange count of things waiting on the owner.',
    build: (context, knobs) => CountBadge(
      count: knobs.longText ? 128 : 2,
      semanticLabel: 'days to confirm',
    ),
  ),
  GalleryDemo(
    id: 'controls/property_sheet_tabs',
    widget: 'PropertySheetTabs',
    summary:
        'Property-sheet tabs; the active one joins the page with a warm top '
        'edge.'
        ' No disabled state, so the Enabled knob does not apply.',
    build: (context, knobs) => SizedBox(
      width: 360,
      child: GalleryValue<int>(
        initial: 0,
        builder: (context, index, select) => PropertySheetTabs(
          labels: [
            'Rate',
            'Premiums',
            'Leave',
            knobs.text('Notes', 'Notes and history of changes'),
          ],
          selectedIndex: index,
          onSelected: select,
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/etched_line',
    widget: 'EtchedLine',
    summary: 'A 2 px etched separator: a grey line over a white one.',
    build: (context, knobs) => const SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Paid time: 11:30'),
          EtchedLine(),
          Text('Est. pay: EUR 211.60'),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_combo',
    widget: 'EraCombo',
    summary:
        'A drop-down list combo; its list drops below with the current value '
        'lit.'
        ' No disabled state, so the Enabled knob does not apply.',
    size: const Size(480, 280),
    build: (context, knobs) => GalleryValue<String>(
      initial: 'effective',
      builder: (context, value, select) => EraCombo<String>(
        items: [
          const EraComboItem('effective', 'Effective'),
          const EraComboItem('all', 'All records'),
          EraComboItem(
            'voided',
            knobs.text('Voided', 'Voided and replaced records'),
          ),
        ],
        value: value,
        onSelected: select,
        semanticLabel: 'Status',
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_field',
    widget: 'EraField',
    summary: '"Label:" and a sunken white text field; an error shows under it.',
    build: (context, knobs) => _FieldDemo(knobs: knobs),
  ),
  GalleryDemo(
    id: 'controls/era_form_scope',
    widget: 'EraFormScope',
    summary:
        "Sets a form's label-column width and greys every era field when "
        'disabled.',
    build: (context, knobs) => SizedBox(
      width: 360,
      child: EraFormScope(
        labelWidth: 120,
        enabled: knobs.enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EraLabelled(label: 'Hourly rate (€)', field: Text('18.40')),
            EraLabelled(
              label: 'Basis',
              field: GalleryValue<String>(
                initial: 'gross',
                builder: (context, value, select) => EraRadioGroup<String>(
                  options: const [
                    EraRadioOption('gross', 'Gross'),
                    EraRadioOption('net', 'Net'),
                  ],
                  groupValue: value,
                  onChanged: knobs.enabled ? select : null,
                  direction: Axis.horizontal,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_labelled',
    widget: 'EraLabelled',
    summary: '"Label:" in the label column, then the field at its kind width.',
    build: (context, knobs) => SizedBox(
      width: 360,
      child: EraLabelled(
        label: knobs.text(
          'Hourly rate (€)',
          'Hourly rate before tax and premiums (€)',
        ),
        fieldWidth: EraFieldWidth.money,
        field: const EraComboFace(value: '18.40'),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_check_box',
    widget: 'EraCheckBox',
    summary: 'A 13 px era check box; the whole row toggles it.',
    build: (context, knobs) => GalleryValue<bool>(
      initial: true,
      builder: (context, value, set) => EraCheckBox(
        value: value,
        onChanged: knobs.enabled ? set : null,
        label: knobs.text(
          'Off days',
          'Show off days between shifts in the list',
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_radio',
    widget: 'EraRadio',
    summary: 'A 13 px era radio with its label; the whole row selects it.',
    build: (context, knobs) => GalleryValue<String>(
      initial: 'gross',
      builder: (context, value, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EraRadio<String>(
            value: 'gross',
            groupValue: value,
            onChanged: knobs.enabled ? set : null,
            label: 'Gross',
          ),
          EraRadio<String>(
            value: 'net',
            groupValue: value,
            onChanged: knobs.enabled ? set : null,
            label: 'Net',
            detail: knobs.text(
              'After tax',
              'After income tax and social insurance',
            ),
          ),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_radio_group',
    widget: 'EraRadioGroup',
    summary: 'Era radios that act as one choice.',
    build: (context, knobs) => GalleryValue<String>(
      initial: 'vacation',
      builder: (context, value, set) => EraRadioGroup<String>(
        options: const [
          EraRadioOption('vacation', 'Vacation'),
          EraRadioOption('sick', 'Sick leave'),
          EraRadioOption('unpaid', 'Unpaid leave'),
        ],
        groupValue: value,
        onChanged: knobs.enabled ? set : null,
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_date_field',
    widget: 'EraDateField',
    summary:
        'A date box ("Wed 2026-10-07") with a drop arrow to the month '
        'calendar.',
    size: const Size(480, 320),
    build: (context, knobs) => GalleryValue<LocalDate?>(
      initial: const LocalDate(2026, 10, 7),
      builder: (context, value, set) => EraDateField(
        label: knobs.text('Starts on', 'Agreement starts on (first paid day)'),
        value: value,
        onChanged: set,
        today: galleryToday,
        error: knobs.errorText,
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_time_field',
    widget: 'EraTimeField',
    summary: 'A time box with spin arrows; its parts are stepped or typed.',
    build: (context, knobs) => GalleryValue<LocalTime?>(
      initial: const LocalTime(19, 45),
      builder: (context, value, set) => EraTimeField(
        label: knobs.text('End', 'End of the shift (next day after midnight)'),
        value: value,
        onChanged: set,
        enabled: knobs.enabled,
        error: knobs.errorText,
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_month_calendar',
    widget: 'EraMonthCalendar',
    summary:
        'The month calendar: Monday-first weeks, today circled, a Today '
        'link.'
        ' No disabled state, so the Enabled knob does not apply.',
    size: const Size(480, 320),
    build: (context, knobs) => GalleryValue<LocalDate?>(
      initial: const LocalDate(2026, 10, 7),
      builder: (context, value, set) =>
          EraMonthCalendar(today: galleryToday, selected: value, onPicked: set),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_menu_label',
    widget: 'EraMenuLabel',
    summary: "A menu row's icon gutter and text; the default command is bold.",
    size: const Size(680, 240),
    build: (context, knobs) => SizedBox(
      width: 620 * knobs.textScale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EraMenuLabel(
            EraMenuItem(
              'Open',
              () {},
              isDefault: true,
              icon: EraIconKind.properties,
            ),
          ),
          EraMenuLabel(
            EraMenuItem(
              knobs.text('Delete', 'Delete this shift and its breaks'),
              () {},
              icon: EraIconKind.delete,
            ),
          ),
          EraMenuLabel(EraMenuItem('Off days', () {}, checked: true)),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_menu_button',
    widget: 'EraMenuButton',
    summary: 'A key that drops an era menu, as Add does.',
    build: (context, knobs) => EraMenuButton(
      items: [
        EraMenuItem('Shift', () {}, icon: EraIconKind.shift),
        EraMenuItem('Pay period', () {}, icon: EraIconKind.payPeriod),
        const EraMenuItem.separator(),
        EraMenuItem('Employment…', () {}, icon: EraIconKind.employment),
      ],
      builder: (context, toggle) => KeyButton(
        label: 'Add',
        kind: KeyKind.toolbar,
        leading: const Orb(glyph: OrbGlyph.add, tone: OrbTone.orange),
        onPressed: knobs.press(toggle),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_context_menu',
    widget: 'EraContextMenu',
    summary:
        'The right-click menu, opened at once with its corner at the pointer.'
        ' No disabled state, so the Enabled knob does not apply.',
    build: (context, knobs) => const _ContextMenuDemo(),
  ),
  GalleryDemo(
    id: 'controls/era_scrollbar',
    widget: 'EraScrollbar',
    summary:
        'The 17 px era scrollbar: arrow keys, a pale track and a blue thumb '
        'with grip lines.',
    build: (context, knobs) => const _ScrollbarDemo(),
  ),
];

final class _FieldDemo extends StatefulWidget {
  const _FieldDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_FieldDemo> createState() => _FieldDemoState();
}

final class _FieldDemoState extends State<_FieldDemo> {
  final _controller = TextEditingController(text: 'Stayed for handover');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: EraField(
      controller: _controller,
      label: widget.knobs.text(
        'Note',
        'A note about this day for the payroll office',
      ),
      error: widget.knobs.errorText,
    ),
  );
}

final class _ContextMenuDemo extends StatefulWidget {
  const _ContextMenuDemo();

  @override
  State<_ContextMenuDemo> createState() => _ContextMenuDemoState();
}

final class _ContextMenuDemoState extends State<_ContextMenuDemo> {
  final _menu = GlobalKey<EraContextMenuState>();

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return EraContextMenu(
      key: _menu,
      child: GestureDetector(
        onSecondaryTapDown: (details) =>
            _menu.currentState?.show(details.globalPosition, [
              EraMenuItem(
                'Open',
                () {},
                isDefault: true,
                icon: EraIconKind.properties,
              ),
              const EraMenuItem.separator(),
              EraMenuItem('Delete', () {}, icon: EraIconKind.delete),
            ]),
        child: Container(
          width: 240,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.paper,
            border: Border.all(color: tokens.chromeLine),
          ),
          child: const Text('Right-click here'),
        ),
      ),
    );
  }
}

final class _ScrollbarDemo extends StatefulWidget {
  const _ScrollbarDemo();

  @override
  State<_ScrollbarDemo> createState() => _ScrollbarDemoState();
}

final class _ScrollbarDemoState extends State<_ScrollbarDemo> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return SizedBox(
      width: 240,
      height: 140,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.paper,
          border: Border.all(color: MillenniumColors.fieldLine),
        ),
        // The era scroll behavior would add a second bar; this demo draws
        // the bar itself.
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: EraScrollbar(
            controller: _controller,
            axis: Axis.vertical,
            child: ListView(
              controller: _controller,
              children: [
                for (var row = 1; row <= 30; row++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text('Row $row'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
