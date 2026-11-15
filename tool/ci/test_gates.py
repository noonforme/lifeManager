"""Failure propagation and output privacy are part of the CI gate contract."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

from run import gate


class GateTests(unittest.TestCase):
    def test_failure_is_nonzero_and_receipt_excludes_child_output(self):
        with tempfile.TemporaryDirectory() as root:
            evidence = Path(root)
            with self.assertRaises(SystemExit) as raised:
                gate('synthetic-fault', [sys.executable, '-c',
                     'print("private sentinel path token SQL"); raise SystemExit(5)'], evidence)
            self.assertEqual(raised.exception.code, 5)
            self.assertEqual(json.loads((evidence / 'synthetic-fault.json').read_text()),
                             {'gate': 'synthetic-fault', 'exit_code': 5, 'status': 'failed',
                              'completion_verified': True})

    def test_success_records_explicit_exit_code(self):
        with tempfile.TemporaryDirectory() as root:
            gate('synthetic-pass', [sys.executable, '-c', 'pass'], Path(root))
            self.assertEqual(json.loads((Path(root) / 'synthetic-pass.json').read_text())['exit_code'], 0)

    def test_zero_exit_without_successful_suite_completion_fails(self):
        for output in ('logged error only', '{"type":"done","success":false}'):
            with self.subTest(output=output), tempfile.TemporaryDirectory() as root:
                with self.assertRaises(SystemExit):
                    gate('incomplete-suite', [sys.executable, '-c',
                         f'print({output!r})'], Path(root), require_test_completion=True)
                receipt = json.loads((Path(root) / 'incomplete-suite.json').read_text())
                self.assertEqual(receipt['exit_code'], 0)
                self.assertEqual(receipt['status'], 'failed')

    def test_zero_exit_with_successful_suite_completion_passes(self):
        with tempfile.TemporaryDirectory() as root:
            gate('complete-suite', [sys.executable, '-c',
                 'print(\'{"type":"done","success":true}\')'], Path(root),
                 require_test_completion=True)
            self.assertTrue(json.loads((Path(root) / 'complete-suite.json').read_text())['completion_verified'])

    def test_signal_cannot_be_success(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaises(SystemExit) as raised:
                gate('synthetic-signal', [sys.executable, '-c',
                     'import os,signal; os.kill(os.getpid(), signal.SIGTERM)'], Path(root))
            self.assertEqual(raised.exception.code, 1)


if __name__ == '__main__':
    unittest.main()
