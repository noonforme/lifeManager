#!/usr/bin/env python3
"""Fail-closed Linux gates. Retain only fixed-vocabulary receipts, never raw output."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[2]
FRAMEWORK = '6a19cca56475dbfba1478ee68d7bd0c2ef891da1'


def gate(name, command, evidence, *, input_text=None, cwd=REPO, require_test_completion=False):
    # Child output may contain paths, SQL or test fixture values. Do not publish it.
    environment = dict(os.environ)
    if require_test_completion:
        environment['LIFEOS_TEST_REPORTER'] = 'json'
    completed = not require_test_completion
    with tempfile.TemporaryFile() as output:
        result = subprocess.run(command, cwd=cwd, input=input_text,
                                text=True, stdout=output, stderr=output, env=environment)
        if require_test_completion:
            output.seek(0)
            for line in output:
                try:
                    event = json.loads(line)
                except (ValueError, UnicodeDecodeError):
                    continue
                if isinstance(event, dict) and event.get('type') == 'done':
                    completed = event.get('success') is True
    passed = result.returncode == 0 and completed
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / f'{name}.json').write_text(json.dumps(
        {'gate': name, 'exit_code': result.returncode,
         'status': 'passed' if passed else 'failed',
         'completion_verified': completed},
        sort_keys=True) + '\n')
    print(f'{name}: {"passed" if passed else "failed"}', flush=True)
    if not passed:
        raise SystemExit(result.returncode if result.returncode > 0 else 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['checks', 'tests', 'operations', 'build'])
    parser.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    flutter = os.environ.get('FLUTTER', 'flutter')
    dart = str(Path(flutter).with_name('dart')) if '/' in flutter else 'dart'
    version = subprocess.run([flutter, '--version', '--machine'], cwd=REPO,
                             capture_output=True, text=True, check=True)
    metadata = json.loads(version.stdout)
    if (json.loads((REPO / '.fvmrc').read_text())['flutter'] != '3.47.5'
            or metadata['frameworkVersion'] != '3.47.5'
            or metadata['frameworkRevision'] != FRAMEWORK
            or metadata['dartSdkVersion'] != '3.13.4'):
        raise SystemExit('Pinned Flutter/Dart toolchain required')
    if args.phase == 'checks':
        gate('locked-dependencies', [flutter, 'pub', 'get', '--enforce-lockfile'], evidence)
        gate('project-checks', ['bash', 'app.sh'], evidence, input_text='3\n6\n')
        gate('privacy', [dart, 'run', 'tool/privacy_scan.dart'], evidence)
    elif args.phase == 'tests':
        gate('flutter-tests', ['bash', 'app.sh'], evidence, input_text='2\n6\n',
             require_test_completion=True)
    elif args.phase == 'operations':
        gate('gate-regressions', [sys.executable, '-m', 'unittest', 'discover',
                                 '-s', 'tool/ci', '-p', 'test_*.py'], evidence)
        gate('operations-tests', [sys.executable, '-W', 'error::ResourceWarning',
                                 '-m', 'unittest', 'discover', '-s', 'tool/operations',
                                 '-p', 'test_*.py', '-v'], evidence)
        for drill in ('lock', 'schema', 'storage'):
            gate(f'drill-{drill}', [sys.executable, 'tool/operations/db_drills.py', drill], evidence)
    else:
        gate('linux-release', [flutter, 'build', 'linux', '--release'], evidence)


if __name__ == '__main__':
    main()
