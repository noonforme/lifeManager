"""Exercise the drill command contract and rejection of false-positive evidence."""
import json
import subprocess
import sys
import unittest
from unittest import mock

import db_drills
import db_health as health


class DrillTests(unittest.TestCase):
    def test_cli_exercises_and_records_all_three_failures_and_recovery(self):
        for name, code in (('lock', 4), ('schema', 3), ('storage', 4)):
            with self.subTest(drill=name):
                result = subprocess.run(
                    [sys.executable, str(health.REPO / 'tool/operations/db_drills.py'), name],
                    capture_output=True, text=True, timeout=25)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                report = json.loads(result.stdout)
                for field in ('symptoms', 'hypothesis', 'evidence', 'diagnosis',
                              'recovery', 'verification', 'prevention', 'cleanup'):
                    self.assertTrue(report[field])
                self.assertEqual(report['evidence']['baseline']['exit_code'], 0)
                self.assertEqual(report['evidence']['fault']['exit_code'], code)
                self.assertEqual(report['evidence']['recovered']['exit_code'], 0)
                self.assertTrue(report['verification']['baseline_bytes_preserved'])
                self.assertTrue(report['verification']['synthetic_record_preserved'])

    def test_unexpected_healthy_fault_signal_fails_the_drill(self):
        # A gate must fail when the unhealthy fixture unexpectedly passes.
        response = subprocess.CompletedProcess([], 0, '{"status":"healthy"}', '')
        with mock.patch.object(db_drills.subprocess, 'run', return_value=response):
            with self.assertRaisesRegex(AssertionError, 'unexpected diagnostic exit code'):
                db_drills.diagnose('/tmp/unused', 'unused-token', 4)

    def test_cli_does_not_accept_existing_data_roots(self):
        result = subprocess.run(
            [sys.executable, str(health.REPO / 'tool/operations/db_drills.py'),
             'storage', '--root', str(health.REPO)],
            capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
