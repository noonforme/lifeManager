"""Only synthetic fixtures; no application/user database is opened."""
import contextlib
import fcntl
import io
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import db_health as health


class HealthTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='lifeos-health-', dir='/tmp')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app, self.version, self.filename, self.marker = health.contract()
        (self.root / self.marker).write_text('synthetic-token')
        (self.root / '.lifeos-synthetic-root').write_bytes(health.SYNTHETIC_MARKER)
        self.db = self.root / self.filename
        with contextlib.closing(sqlite3.connect(self.db)) as connection, connection:
            sql = (health.REPO / 'test/core/database/fixtures/schema_v3.sql').read_text()
            connection.executescript(sql)
            for table in ('desk_tiles', 'desks', 'saved_views'):
                connection.execute('DROP TABLE ' + table)
            connection.execute(f'PRAGMA application_id={self.app}')
            connection.execute(f'PRAGMA user_version={self.version}')

    def run_health(self, root=None, token='synthetic-token'):
        # CLI output is part of the contract, including sanitization and exit status.
        p = subprocess.run([str(health.REPO / 'tool/operations/db-health.sh'),
                            '--root', str(root or self.root), '--marker-token', token],
                           capture_output=True, text=True, timeout=7)
        self.assertEqual(p.stderr, '')
        self.assertNotIn(str(self.root), p.stdout)
        self.assertNotIn(token, p.stdout)
        return json.loads(p.stdout), p.returncode

    def test_healthy_stable_json_and_source_unchanged(self):
        before = self.db.read_bytes()
        result, code = self.run_health()
        self.assertEqual(code, 0)
        self.assertEqual(result['status'], 'healthy')
        self.assertTrue(result['identity']['matches'])
        self.assertTrue(result['schema']['structure_matches'])
        self.assertEqual(result['foreign_keys']['violation_count'], 0)
        self.assertEqual(self.run_health(), (result, code))
        self.assertEqual(before, self.db.read_bytes())
        self.assertEqual(len(list(self.root.iterdir())), 3)

    def test_invalid_roots_never_reach_sqlite(self):
        for root in (health.REPO, Path.home(), Path('/tmp'), self.root / 'missing'):
            with self.subTest(root=root), mock.patch.object(health.sqlite3, 'connect') as connect:
                with self.assertRaises((health.Refusal, OSError)):
                    health.diagnose(str(root), 'synthetic-token')
                connect.assert_not_called()

    def test_marker_mismatch_and_missing_synthetic_declaration(self):
        self.assertEqual(self.run_health(token='incorrect')[1], 2)
        (self.root / '.lifeos-synthetic-root').unlink()
        self.assertEqual(self.run_health()[1], 2)

    def test_symlinked_root_ancestor_database_marker_and_hardlink(self):
        link = self.root / 'link'
        link.symlink_to(self.root, target_is_directory=True)
        self.assertEqual(self.run_health(root=link)[1], 2)
        self.assertEqual(self.run_health(root=link / 'link')[1], 2)
        for name in (self.filename, self.marker, '.lifeos-synthetic-root'):
            path = self.root / name
            saved = self.root / 'saved'
            path.rename(saved)
            path.symlink_to(saved)
            self.assertEqual(self.run_health()[1], 2)
            path.unlink()
            saved.rename(path)
        os.link(self.db, self.root / 'hardlink')
        self.assertEqual(self.run_health()[1], 2)

    def test_unowned_root_and_file_rejected(self):
        original = os.getuid()
        with mock.patch.object(health.os, 'getuid', return_value=original + 1):
            with self.assertRaises(health.Refusal):
                health.diagnose(str(self.root), 'synthetic-token')
        st = self.db.stat()
        with mock.patch.object(health.os, 'getuid', return_value=st.st_uid + 1):
            with self.assertRaises(health.Refusal):
                health.owned(st)

    def test_unowned_database_refused_before_open(self):
        real_stat = health.os.stat
        real_open = health.os.open
        opened = []
        def fake_stat(path, *args, **kwargs):
            st = real_stat(path, *args, **kwargs)
            if path == self.filename:
                values = list(st)
                values[4] = os.getuid() + 1
                return os.stat_result(values)
            return st
        def checked_open(path, *args, **kwargs):
            opened.append(path)
            return real_open(path, *args, **kwargs)
        with mock.patch.object(health.os, 'stat', side_effect=fake_stat), \
             mock.patch.object(health.os, 'open', side_effect=checked_open), \
             mock.patch.object(health.sqlite3, 'connect') as connect:
            with self.assertRaises(health.Refusal):
                health.diagnose(str(self.root), 'synthetic-token')
        self.assertNotIn(self.filename, opened)
        connect.assert_not_called()

    def test_unsafe_permissions_and_fifo(self):
        self.root.chmod(0o755)
        self.assertEqual(self.run_health()[1], 2)
        self.root.chmod(0o700)
        self.db.unlink()
        os.mkfifo(self.db)
        self.assertEqual(self.run_health()[1], 2)

    def test_incompatible_identity_version_and_structure_no_migration(self):
        for sql in ('PRAGMA application_id=7', f'PRAGMA application_id={self.app}; PRAGMA user_version=2',
                    f'PRAGMA user_version={self.version}; DROP TABLE preferences'):
            with contextlib.closing(sqlite3.connect(self.db)) as connection, connection:
                connection.executescript(sql)
            before = self.db.read_bytes()
            self.assertEqual(self.run_health()[1], 3)
            self.assertEqual(before, self.db.read_bytes())

    def test_missing_database_unavailable_not_created(self):
        self.db.unlink()
        self.assertEqual(self.run_health()[1], 4)
        self.assertFalse(self.db.exists())

    def test_corrupt_database_unhealthy_no_details(self):
        self.db.write_bytes(b'private-path raw SQL secret exception')
        result, code = self.run_health()
        self.assertEqual(code, 5)
        self.assertEqual(result['status'], 'unhealthy')
        self.assertNotIn('secret', json.dumps(result))

    def test_fk_violation_redacts_record_content(self):
        with contextlib.closing(sqlite3.connect(self.db)) as connection, connection:
            connection.execute("INSERT INTO shift_breaks VALUES ('private-secret', 'missing-secret', 1, 2, 1, 1, 0)")
        result, code = self.run_health()
        self.assertEqual(code, 5)
        self.assertEqual(result['foreign_keys']['violation_count'], 1)
        self.assertNotIn('secret', json.dumps(result))

    def test_integrity_violation(self):
        with contextlib.closing(sqlite3.connect(self.db)) as connection, connection:
            connection.execute('PRAGMA ignore_check_constraints=ON')
            connection.execute("INSERT INTO employments VALUES ('x','synthetic',NULL,'active',1,1,-1)")
        result, code = self.run_health()
        self.assertEqual(code, 5)
        self.assertFalse(result['integrity']['ok'])

    def test_wal_and_journal_refused_without_mutation(self):
        for suffix in ('-wal', '-shm', '-journal'):
            sidecar = Path(str(self.db) + suffix)
            sidecar.write_bytes(b'synthetic pending data')
            before = {p.name: p.read_bytes() for p in self.root.iterdir()}
            self.assertEqual(self.run_health()[1], 4)
            self.assertEqual(before, {p.name: p.read_bytes() for p in self.root.iterdir()})
            sidecar.unlink()

    def test_checkpointed_wal_header_supported(self):
        with contextlib.closing(sqlite3.connect(self.db)) as connection, connection:
            connection.execute('PRAGMA journal_mode=WAL')
        connection.close()
        result, code = self.run_health()
        self.assertEqual(code, 0)
        self.assertEqual(result['settings']['source_journal_mode'], 'wal')

    def test_exclusive_lock_fails_fast(self):
        with contextlib.closing(sqlite3.connect(self.db)) as connection, connection:
            connection.execute('BEGIN EXCLUSIVE')
            start = time.monotonic()
            self.assertEqual(self.run_health()[1], 4)
            self.assertLess(time.monotonic() - start, 2)

    def test_active_wal_is_unavailable_and_unchanged(self):
        with contextlib.closing(sqlite3.connect(self.db)) as connection:
            connection.execute('PRAGMA journal_mode=WAL')
            connection.execute("INSERT INTO core_metadata(id) VALUES (1)")
            connection.commit()
            before = self.db.read_bytes()
            wal = Path(str(self.db) + '-wal').read_bytes()
            self.assertEqual(self.run_health()[1], 4)
            self.assertEqual(before, self.db.read_bytes())
            self.assertEqual(wal, Path(str(self.db) + '-wal').read_bytes())

    def test_production_support_root_even_under_tmp_refused(self):
        with mock.patch.dict(os.environ, {'XDG_DATA_HOME': str(self.root)}):
            with self.assertRaises(health.Refusal):
                health.diagnose(str(self.root), 'synthetic-token')

    def test_symlink_sidecar_rejected(self):
        Path(str(self.db) + '-wal').symlink_to(self.db)
        self.assertEqual(self.run_health()[1], 2)

    def test_same_columns_wrong_types_or_missing_fk_incompatible(self):
        with contextlib.closing(sqlite3.connect(self.db)) as connection, connection:
            connection.execute('DROP TABLE shift_breaks')
            connection.execute('CREATE TABLE shift_breaks (id TEXT NOT NULL PRIMARY KEY, '
                               'shift_id TEXT NOT NULL, start_utc_micros TEXT NOT NULL, '
                               'end_utc_micros INTEGER, created_at_utc_micros INTEGER NOT NULL, '
                               'updated_at_utc_micros INTEGER NOT NULL, revision INTEGER NOT NULL)')
        self.assertEqual(self.run_health()[1], 3)

    def test_invalid_arguments_sanitized(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = health.main(['--private-secret'])
        self.assertEqual(code, 2)
        self.assertNotIn('private-secret', output.getvalue())


if __name__ == '__main__':
    unittest.main()
