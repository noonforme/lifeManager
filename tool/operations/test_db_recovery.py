"""Synthetic recovery tests, including WAL-only commits and failed publication."""
import contextlib
import errno
import io
import json
import os
from pathlib import Path
import shutil
import signal
import sqlite3
import subprocess
import sys
import time
import unittest
import uuid
from unittest import mock

import db_health as health
import db_recovery as recovery
import test_db_health


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        test_db_health.HealthTests.setUp(self)

    def destination(self):
        path = Path('/tmp/lifeos-recovery-' + uuid.uuid4().hex)
        def cleanup():
            if path.exists():
                self.assertEqual((path / self.marker).read_text(), 'recovery-token')
                shutil.rmtree(path)
        self.addCleanup(cleanup)
        return path

    def transfer(self, operation='backup', root=None, destination=None, **kwargs):
        return recovery.transfer(operation, str(root or self.root),
                                 'synthetic-token' if root is None else 'recovery-token',
                                 str(destination or self.destination()), 'recovery-token', **kwargs)

    def cli(self, *args):
        p = subprocess.run([str(health.REPO / 'tool/operations/db-recovery.sh'), *args],
                           text=True, capture_output=True, timeout=12)
        self.assertEqual(p.stderr, '')
        self.assertNotIn(str(self.root), p.stdout)
        self.assertNotIn('token', p.stdout)
        return json.loads(p.stdout), p.returncode

    def test_wal_commits_snapshot_restore_and_source_preserved(self):
        with contextlib.closing(sqlite3.connect(self.db)) as writer:
            writer.execute('PRAGMA journal_mode=WAL')
            writer.execute('PRAGMA wal_autocheckpoint=0')
            writer.execute("INSERT INTO employments VALUES ('lab','Synthetic WAL',NULL,'active',1,1,0)")
            writer.execute("INSERT INTO preferences VALUES ('appearance','night')")
            writer.commit()
            before = self.db.read_bytes()
            wal = Path(str(self.db) + '-wal').read_bytes()
            self.assertGreater(len(wal), 32)
            # Prove main file alone does not contain the committed row.
            memory = sqlite3.connect(':memory:')
            self.addCleanup(memory.close)
            image = before[:18] + b'\x01\x01' + before[20:]
            memory.deserialize(image)
            self.assertEqual(memory.execute('SELECT count(*) FROM employments').fetchone()[0], 0)
            backup = self.destination()
            result, code = self.transfer(destination=backup)
            self.assertEqual(code, 0)
            self.assertTrue(result['records_match'])
            restored = self.destination()
            self.assertEqual(self.transfer('restore', root=backup, destination=restored)[1], 0)
            with contextlib.closing(sqlite3.connect(restored / self.filename)) as check:
                self.assertEqual(check.execute('SELECT name FROM employments').fetchone()[0], 'Synthetic WAL')
                self.assertEqual(check.execute('SELECT value FROM preferences').fetchone()[0], 'night')
            self.assertEqual(before, self.db.read_bytes())
            self.assertEqual(wal, Path(str(self.db) + '-wal').read_bytes())

    def test_read_snapshot_excludes_later_concurrent_commit(self):
        with contextlib.closing(sqlite3.connect(self.db)) as writer:
            writer.execute('PRAGMA journal_mode=WAL')
            writer.execute("INSERT INTO preferences VALUES ('appearance','before')")
            writer.commit()
            def concurrent(*args):
                writer.execute("UPDATE preferences SET value='after'")
                writer.commit()
            backup = self.destination()
            self.transfer(destination=backup, progress_hook=concurrent)
            with contextlib.closing(sqlite3.connect(backup / self.filename)) as check:
                self.assertEqual(check.execute('SELECT value FROM preferences').fetchone()[0], 'before')
            self.assertEqual(writer.execute('SELECT value FROM preferences').fetchone()[0], 'after')

    def test_cli_roundtrip_and_overwrite_refusal(self):
        dest = self.destination()
        args = ['backup', '--root', str(self.root), '--marker-token', 'synthetic-token',
                '--destination', str(dest), '--destination-token', 'recovery-token']
        self.assertEqual(self.cli(*args)[1], 0)
        before = {p.name: p.read_bytes() for p in dest.iterdir()}
        self.assertEqual(self.cli(*args)[1], 2)
        self.assertEqual(before, {p.name: p.read_bytes() for p in dest.iterdir()})
        restored = self.destination()
        self.assertEqual(self.cli('restore', '--root', str(dest), '--marker-token', 'recovery-token',
                                 '--destination', str(restored), '--destination-token', 'recovery-token')[1], 0)

    def test_unsafe_roots_and_destination_never_open_sqlite(self):
        for path in (health.REPO, Path('/tmp'), self.root / 'link', Path('relative')):
            with self.subTest(path=path), mock.patch.object(recovery.sqlite3, 'connect') as connect:
                with self.assertRaises((health.Refusal, OSError)):
                    self.transfer(root=path)
                connect.assert_not_called()
        for dest in (self.root, Path('/tmp/arbitrary-name'), health.REPO / 'unsafe', Path('relative')):
            with self.assertRaises((health.Refusal, OSError)):
                recovery.Destination(str(dest), 'token')
        link = self.root / 'link'
        link.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(health.Refusal):
            self.transfer(root=link)

    def test_unsafe_database_sidecars_and_markers(self):
        for name in (self.filename, self.marker, '.lifeos-synthetic-root', self.filename + '-wal'):
            path = self.root / name
            saved = self.root / 'saved'
            existed = path.exists()
            if existed:
                path.rename(saved)
            path.symlink_to(saved if existed else self.db)
            with mock.patch.object(recovery.sqlite3, 'connect') as connect:
                with self.assertRaises((health.Refusal, OSError)):
                    self.transfer()
                connect.assert_not_called()
            path.unlink()
            if existed:
                saved.rename(path)
        os.link(self.db, self.root / 'hardlink')
        with self.assertRaises(health.Refusal):
            self.transfer()

    def test_incompatible_corrupt_and_fk_failures_leave_no_destination(self):
        for sql, code in [('PRAGMA application_id=7', 3),
                          (f'PRAGMA application_id={self.app}; PRAGMA user_version=2', 3),
                          (f'PRAGMA user_version={self.version}; DROP TABLE preferences', 3),
                          ("INSERT INTO shift_breaks VALUES ('b','missing',1,2,1,1,0)", 3)]:
            with contextlib.closing(sqlite3.connect(self.db)) as connection:
                connection.executescript(sql)
            dest = self.destination()
            with self.assertRaises(health.Refusal) as failure:
                self.transfer(destination=dest)
            self.assertEqual(failure.exception.code, code)
            self.assertFalse(dest.exists())
        self.db.write_bytes(b'synthetic corruption')
        dest = self.destination()
        with self.assertRaises(sqlite3.Error):
            self.transfer(destination=dest)
        self.assertFalse(dest.exists())

    def test_fk_unhealthy_and_interrupt_remove_only_created_root(self):
        with contextlib.closing(sqlite3.connect(self.db)) as connection:
            connection.execute("INSERT INTO shift_breaks VALUES ('b','missing',1,2,1,1,0)")
            connection.commit()
        dest = self.destination()
        with self.assertRaises(health.Refusal) as failure:
            self.transfer(destination=dest)
        self.assertEqual(failure.exception.code, 5)
        self.assertFalse(dest.exists())
        with contextlib.closing(sqlite3.connect(self.db)) as connection:
            connection.execute('DELETE FROM shift_breaks')
            connection.commit()
        def interrupt(*args):
            raise health.Refusal('interrupted', 6)
        with self.assertRaises(health.Refusal):
            self.transfer(destination=dest, progress_hook=interrupt)
        self.assertFalse(dest.exists())
        self.assertTrue(self.db.exists())

    def test_signal_interruption_is_sanitized_and_unpublished(self):
        dest = self.destination()
        def interrupt(*args):
            os.kill(os.getpid(), signal.SIGTERM)
        output = io.StringIO()
        original = recovery.transfer
        with mock.patch.object(recovery, 'transfer', side_effect=lambda *a: original(*a, progress_hook=interrupt)), \
             contextlib.redirect_stdout(output):
            code = recovery.main(['backup', '--root', str(self.root), '--marker-token', 'synthetic-token',
                                  '--destination', str(dest), '--destination-token', 'recovery-token'])
        self.assertEqual(code, 6)
        self.assertEqual(json.loads(output.getvalue())['status'], 'interrupted')
        self.assertFalse(dest.exists())

    def test_snapshot_hash_and_manifest_required_for_restore(self):
        backup = self.destination()
        self.transfer(destination=backup)
        db = backup / self.filename
        with contextlib.closing(sqlite3.connect(db)) as connection:
            connection.execute("INSERT INTO preferences VALUES ('appearance','tampered')")
            connection.commit()
        with self.assertRaises(health.Refusal):
            self.transfer('restore', root=backup)
        (backup / recovery.MANIFEST).unlink()
        with self.assertRaises(FileNotFoundError):
            self.transfer('restore', root=backup)

    def test_locked_source_is_bounded_and_no_destination(self):
        with contextlib.closing(sqlite3.connect(self.db)) as writer:
            writer.execute('BEGIN EXCLUSIVE')
            start = time.monotonic()
            dest = self.destination()
            with self.assertRaises(sqlite3.Error):
                self.transfer(destination=dest)
            self.assertLess(time.monotonic() - start, 1)
            self.assertFalse(dest.exists())

    def test_sigkill_leaves_unpublished_root_that_restore_refuses(self):
        dest = self.destination()
        program = """
import os, signal, sys
sys.path.insert(0, 'tool/operations')
import db_recovery as r
r.transfer('backup', sys.argv[1], 'synthetic-token', sys.argv[2], 'recovery-token',
           progress_hook=lambda *args: os.kill(os.getpid(), signal.SIGKILL))
"""
        process = subprocess.run([sys.executable, '-c', program, str(self.root), str(dest)],
                                 capture_output=True, timeout=7)
        self.assertEqual(process.returncode, -signal.SIGKILL)
        self.assertTrue(dest.is_dir())
        self.assertFalse((dest / recovery.MANIFEST).exists())
        self.assertEqual(self.cli('restore', '--root', str(dest), '--marker-token', 'recovery-token',
                                 '--destination', str(self.destination()),
                                 '--destination-token', 'recovery-token')[1], 4)

    def test_deadline_and_storage_failure_clean_up(self):
        dest = self.destination()
        original = recovery.Destination.write
        def fail_write(target, name, data):
            if name == recovery.MANIFEST:
                raise OSError(28, 'synthetic full storage')
            return original(target, name, data)
        with mock.patch.object(recovery.Destination, 'write', fail_write):
            with self.assertRaises(OSError):
                self.transfer(destination=dest)
        self.assertFalse(dest.exists())
        with mock.patch.object(recovery.time, 'monotonic', side_effect=[0] + [100] * 100):
            with self.assertRaises((health.Refusal, sqlite3.Error)):
                self.transfer(destination=dest)
        self.assertFalse(dest.exists())

    def test_cli_failure_codes_and_sanitization(self):
        args = ['backup', '--root', str(self.root), '--marker-token', 'synthetic-token',
                '--destination', str(self.destination()), '--destination-token', 'recovery-token']
        self.assertEqual(self.cli('--private-secret')[1], 2)
        with contextlib.closing(sqlite3.connect(self.db)) as connection:
            connection.execute('BEGIN EXCLUSIVE')
            result, code = self.cli(*args)
            self.assertEqual((result['status'], code), ('unavailable', 4))
            connection.rollback()
            connection.execute('PRAGMA application_id=7')
        result, code = self.cli(*args)
        self.assertEqual((result['status'], code), ('incompatible', 3))
        self.db.write_bytes(b'synthetic corruption secret exception SQL')
        result, code = self.cli(*args)
        self.assertEqual((result['status'], code), ('unhealthy', 5))
        self.assertNotIn('secret', json.dumps(result))
        self.db.unlink()
        self.assertEqual(self.cli(*args)[1], 4)

    def test_recovery_root_permissions_and_marker_mismatch(self):
        self.root.chmod(0o755)
        with mock.patch.object(recovery.sqlite3, 'connect') as connect:
            with self.assertRaises(health.Refusal):
                self.transfer()
            connect.assert_not_called()
        self.root.chmod(0o700)
        (self.root / self.marker).write_text('other')
        with mock.patch.object(recovery.sqlite3, 'connect') as connect:
            with self.assertRaises(health.Refusal):
                self.transfer()
            connect.assert_not_called()

    def acquisition_cli(self, destination):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = recovery.main(['backup', '--root', str(self.root),
                                  '--marker-token', 'synthetic-token',
                                  '--destination', str(destination),
                                  '--destination-token', 'recovery-token'])
        return json.loads(output.getvalue()), code

    def test_caught_signals_before_markers_close_descriptors_and_remove_root(self):
        for phase in ('mkdir', 'open', 'fstat', 'constructor_return'):
            for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGALRM):
                with self.subTest(phase=phase, signal=sig):
                    dest = self.destination()
                    descriptors = []
                    injected = []
                    real_mkdir, real_open, real_fstat = os.mkdir, os.open, os.fstat
                    real_destination = recovery.Destination
                    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, set())
                    before_fds = set(os.listdir('/proc/self/fd'))
                    def inject(at):
                        if phase == at and not injected:
                            self.assertFalse((dest / self.marker).exists() and at != 'constructor_return')
                            injected.append(at)
                            os.kill(os.getpid(), sig)
                    def mkdir(path, *a, **kw):
                        result = real_mkdir(path, *a, **kw)
                        if Path(path) == dest:
                            inject('mkdir')
                        return result
                    def opened(path, *a, **kw):
                        fd = real_open(path, *a, **kw)
                        if path == dest:
                            descriptors.append(fd)
                            inject('open')
                        return fd
                    def fstat(fd):
                        if fd in descriptors:
                            inject('fstat')
                        return real_fstat(fd)
                    def constructed(*a, **kw):
                        target = real_destination(*a, **kw)
                        inject('constructor_return')
                        return target
                    with mock.patch.object(recovery.os, 'mkdir', side_effect=mkdir), \
                         mock.patch.object(recovery.os, 'open', side_effect=opened), \
                         mock.patch.object(recovery.os, 'fstat', side_effect=fstat), \
                         mock.patch.object(recovery, 'Destination', side_effect=constructed):
                        result, code = self.acquisition_cli(dest)
                    self.assertEqual(injected, [phase])
                    self.assertEqual(code, 4 if sig == signal.SIGALRM else 6)
                    self.assertEqual(result['status'], 'unavailable' if sig == signal.SIGALRM else 'interrupted')
                    self.assertFalse(dest.exists())
                    for fd in descriptors:
                        with self.assertRaises(OSError) as failure:
                            real_fstat(fd)
                        self.assertEqual(failure.exception.errno, errno.EBADF)
                    self.assertEqual(set(os.listdir('/proc/self/fd')), before_fds)
                    self.assertEqual(signal.pthread_sigmask(signal.SIG_BLOCK, set()), previous_mask)

    def test_open_fstat_and_first_marker_failures_clean_new_root(self):
        for phase in ('open', 'fstat', 'first_marker'):
            with self.subTest(phase=phase):
                dest = self.destination()
                descriptors = []
                real_open, real_fstat = os.open, os.fstat
                real_write = recovery.Destination.write
                def opened(path, *a, **kw):
                    if path == dest and phase == 'open':
                        raise OSError(errno.EMFILE, 'synthetic descriptor exhaustion')
                    fd = real_open(path, *a, **kw)
                    if path == dest:
                        descriptors.append(fd)
                    return fd
                def fstat(fd):
                    if fd in descriptors and phase == 'fstat':
                        raise OSError(errno.EIO, 'synthetic stat failure')
                    return real_fstat(fd)
                def write(target, name, data):
                    if phase == 'first_marker' and name == self.marker:
                        self.assertEqual(os.listdir(dest), [])
                        raise OSError(errno.ENOSPC, 'synthetic marker failure')
                    return real_write(target, name, data)
                before_fds = set(os.listdir('/proc/self/fd'))
                with mock.patch.object(recovery.os, 'open', side_effect=opened), \
                     mock.patch.object(recovery.os, 'fstat', side_effect=fstat), \
                     mock.patch.object(recovery.Destination, 'write', write):
                    result, code = self.acquisition_cli(dest)
                self.assertEqual((result['status'], code), ('unavailable', 4))
                self.assertFalse(dest.exists())
                self.assertEqual(set(os.listdir('/proc/self/fd')), before_fds)

    def test_constructor_itself_handles_pending_signal_and_cleanup_signal(self):
        dest = self.destination()
        original_fstat, original_rmdir = os.fstat, os.rmdir
        injected = []
        def fstat(fd):
            if os.readlink('/proc/self/fd/' + str(fd)) == str(dest) and not injected:
                injected.append('acquire')
                os.kill(os.getpid(), signal.SIGTERM)
            return original_fstat(fd)
        def rmdir(path, *args, **kwargs):
            result = original_rmdir(path, *args, **kwargs)
            if Path(path) == dest:
                injected.append('cleanup')
                os.kill(os.getpid(), signal.SIGTERM)
            return result
        def handler(*args):
            raise health.Refusal('interrupted', 6)
        previous = signal.signal(signal.SIGTERM, handler)
        before_fds = set(os.listdir('/proc/self/fd'))
        try:
            with mock.patch.object(recovery.os, 'fstat', side_effect=fstat), \
                 mock.patch.object(recovery.os, 'rmdir', side_effect=rmdir):
                with self.assertRaises(health.Refusal):
                    recovery.Destination(str(dest), 'recovery-token')
        finally:
            signal.signal(signal.SIGTERM, previous)
        self.assertEqual(injected, ['acquire', 'cleanup'])
        self.assertFalse(dest.exists())
        self.assertEqual(set(os.listdir('/proc/self/fd')), before_fds)

    def test_cleanup_refuses_unexpected_entries_and_existing_roots(self):
        dest = self.destination()
        owned = recovery.Destination(str(dest), 'recovery-token')
        (dest / 'unexpected').write_text('synthetic retained')
        owned.close()
        self.assertTrue((dest / 'unexpected').exists())
        with self.assertRaises(FileExistsError):
            recovery.Destination(str(dest), 'recovery-token')


if __name__ == '__main__':
    unittest.main()
