import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controls/era_scrollbar.dart';
import '../controls/keys.dart';
import '../data/operational_state.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';

/// One package's (or font's) licence: who it covers and the full text.
@immutable
final class LicenceEntry {
  const LicenceEntry({required this.packages, required this.text});

  final List<String> packages;
  final String text;
}

/// Loads the licences to show. A failed future shows the failure state.
typedef LicenceLoader = Future<List<LicenceEntry>> Function();

/// The licences Flutter collected from the app's packages and fonts.
Future<List<LicenceEntry>> loadRegistryLicences() async {
  final entries = await LicenseRegistry.licenses.toList();
  return [
    for (final entry in entries)
      LicenceEntry(
        packages: entry.packages.toList(),
        text: entry.paragraphs.map((p) => p.text).join('\n\n'),
      ),
  ];
}

/// The Licences page: a title, a Back key and the read-only licence text of
/// every package and font. Loading, empty and failed loads each say so (a
/// failure offers Retry); the list builds lazily and scrolls under the bar,
/// so Back stays reachable at any text size.
///
/// Back and Retry are mouse keys: they take no focus and Enter or Space
/// never activates them. [onBack] is a plain callback; the owner guards or
/// flushes any pending edit before leaving.
final class LicencesPage extends StatefulWidget {
  const LicencesPage({
    required this.onBack,
    this.loader = loadRegistryLicences,
    this.title = 'Licences',
    super.key,
  });

  /// Null greys Back.
  final VoidCallback? onBack;

  /// Replaced loader (a different function) reloads; keep it stable.
  final LicenceLoader loader;
  final String title;

  @override
  State<LicencesPage> createState() => _LicencesPageState();
}

final class _LicencesPageState extends State<LicencesPage> {
  final _scroll = ScrollController();
  List<LicenceEntry>? _entries;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LicencesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) _load();
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    super.dispose();
  }

  void _load() {
    final generation = ++_generation;
    _entries = null;
    _failed = false;
    Future<List<LicenceEntry>> future;
    try {
      future = widget.loader();
    } on Object {
      future = Future.error(StateError('Licence loader threw.'));
    }
    future.then<void>(
      (entries) {
        if (!mounted || generation != _generation) return;
        setState(() => _entries = entries);
      },
      onError: (Object _) {
        if (!mounted || generation != _generation) return;
        setState(() => _failed = true);
      },
    );
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final entries = _entries;
    Widget body;
    var state = true;
    if (_failed) {
      body = OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Licences could not be loaded',
        message: 'The licence list is unavailable. Try again.',
        action: ExcludeFocus(
          child: Align(
            alignment: Alignment.centerLeft,
            child: KeyButton(label: 'Retry', onPressed: _retry),
          ),
        ),
      );
    } else if (entries == null) {
      body = const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Loading licences',
        message: 'Reading the package and font licences.',
      );
    } else if (entries.isEmpty) {
      body = const OperationalState(
        kind: OperationalStateKind.empty,
        title: 'No licences',
        message: 'No package or font licences are listed.',
      );
    } else {
      state = false;
      body = EraScrollbar(
        controller: _scroll,
        axis: Axis.vertical,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(6),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.packages.join(', '),
                      style: skin.typography.strong.copyWith(color: tokens.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.text,
                      style: skin.typography.small.copyWith(color: tokens.ink),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }
    if (state) {
      // A state message scrolls rather than overflows a small page.
      final message = body;
      body = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: message,
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tokens.chrome,
              border: Border(bottom: BorderSide(color: tokens.chromeLine)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ExcludeFocus(
                  child: KeyButton(label: 'Back', onPressed: widget.onBack),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: skin.typography.strong.copyWith(color: tokens.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.paper,
                border: Border.all(color: MillenniumColors.fieldLine),
              ),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}
