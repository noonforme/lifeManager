import 'dart:io';

/// Checks of `lib/ui/CATALOG.md` against the library source, kept pure so
/// their negative cases can be tested on small texts.

final _code = RegExp('`([^`]+)`');
final _typeName = RegExp(r'\b[A-Z]\w*');
final _anyHeading = RegExp(r'^##', multiLine: true);

/// The source of every library file outside the gallery, keyed by its path
/// relative to `lib/ui/`: `'controls/keys.dart'`.
Map<String, String> librarySources() => {
  for (final file in Directory('lib/ui').listSync(recursive: true))
    if (file is File &&
        file.path.endsWith('.dart') &&
        !file.path.startsWith('lib/ui/gallery/'))
      file.path.substring('lib/ui/'.length): file.readAsStringSync(),
};

/// Whether [source] declares [name] at the top level: a class, enum,
/// typedef, mixin or extension, or a column-0 function, getter, variable
/// or constant. A mere mention (a parameter or return type) does not count.
bool declaresTopLevel(String source, String name) {
  final n = RegExp.escape(name);
  const declaration =
      r'^(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
      r'(?:class|enum|typedef|mixin|extension(?:\s+type)?)\s+';
  const value = r'^(?!import|export|part|library|return|//|\s)[^\n=(]*\b';
  const valueEnd = r'\s*(?:[(<=;]|=>)';
  const getter = r'^(?!import|export|//|\s)[^\n=(]*\bget\s+';
  return RegExp('$declaration$n\\b', multiLine: true).hasMatch(source) ||
      RegExp('$value$n$valueEnd', multiLine: true).hasMatch(source) ||
      RegExp('$getter$n\\b', multiLine: true).hasMatch(source);
}

/// The body of the entry whose heading ends at [start]: up to the next
/// `##` or `###` heading, so a section's last entry does not run into the
/// next section.
String catalogEntryBody(String catalog, int start) {
  final rest = catalog.substring(start);
  final next = _anyHeading.firstMatch(rest);
  return next == null ? rest : rest.substring(0, next.start);
}

/// Capitalised names in backticks in the Use column of the job table that
/// no library source declares.
List<String> undeclaredJobTableNames(
  String catalog,
  Map<String, String> sources,
) {
  final start = catalog.indexOf('## Which widget for which job');
  if (start < 0) return ['no job table'];
  final end = catalog.indexOf('\n## ', start + 1);
  final table = catalog.substring(start, end < 0 ? catalog.length : end);
  return [
    for (final row in table.split('\n'))
      if (row.startsWith('| ') && !row.startsWith('| Job '))
        for (final code in _code.allMatches(row.split('|')[2]))
          for (final name in _typeName.allMatches(code.group(1)!))
            if (!sources.values.any(
              (source) => declaresTopLevel(source, name.group(0)!),
            ))
              name.group(0)!,
  ];
}

/// Names in the Foundation list that the file named on their line does not
/// declare, as `name (file)`, plus every list line not in the
/// "- `A`, `B` (`foundation/x.dart`): …" format.
List<String> undeclaredFoundationNames(
  String catalog,
  Map<String, String> sources,
) {
  final start = catalog.indexOf('## Foundation');
  if (start < 0) return ['no Foundation section'];
  final end = catalog.indexOf('\n### ', start);
  final section = catalog.substring(start, end < 0 ? catalog.length : end);
  final line = RegExp(r'^- (.*) \(`(foundation/[\w/]+\.dart)`\):');
  final problems = <String>[];
  for (final text in section.split('\n')) {
    if (!text.startsWith('- ')) continue;
    final match = line.firstMatch(text);
    if (match == null) {
      problems.add('unparsed: $text');
      continue;
    }
    final source = sources[match.group(2)!] ?? '';
    for (final code in _code.allMatches(match.group(1)!)) {
      final name = RegExp(r'\w+').firstMatch(code.group(1)!)!.group(0)!;
      if (!declaresTopLevel(source, name)) {
        problems.add('$name (${match.group(2)})');
      }
    }
  }
  return problems;
}
