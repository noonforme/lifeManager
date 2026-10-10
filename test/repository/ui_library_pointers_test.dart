import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Future sessions find the UI library (database shell spec 5.5).
void main() {
  test(
    'instructions, the design record and the skill point at the catalog',
    () {
      for (final path in [
        'CLAUDE.md',
        'AGENTS.md',
        'DESIGN.md',
        '.claude/skills/lifeos-ui/SKILL.md',
        '.agents/skills/lifeos-ui/SKILL.md',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('lib/ui/CATALOG.md'),
          reason: path,
        );
      }
    },
  );

  test('the Codex skill mirrors the Claude skill', () {
    final skill = File('.claude/skills/lifeos-ui/SKILL.md').readAsStringSync();
    expect(skill, startsWith('---\nname: lifeos-ui\ndescription: '));
    expect(File('.agents/skills/lifeos-ui/SKILL.md').readAsStringSync(), skill);
    expect(
      File('.agents/skills/lifeos-ui/agents/openai.yaml').existsSync(),
      isTrue,
    );
  });

  test('the skill updates only the new demo\'s goldens', () {
    final skill = File('.claude/skills/lifeos-ui/SKILL.md').readAsStringSync();
    final updates = RegExp(r'flutter test [^`]*--update-goldens[^`]*')
        .allMatches(skill)
        .map((match) => match.group(0)!)
        .toList();
    expect(updates, hasLength(2));
    for (final command in updates) {
      expect(command, contains('--plain-name'), reason: command);
    }
  });
}
