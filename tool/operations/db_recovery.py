#!/usr/bin/env python3
"""Linux synthetic lab snapshots and restore; never a production restore tool."""
import errno
from contextlib import contextmanager, closing
import hashlib
import json
import os
from pathlib import Path
import signal
import sqlite3
import stat
import sys
import time

import db_health as health

MANIFEST = '.lifeos-snapshot.json'
HANDLED_SIGNALS = {signal.SIGALRM, signal.SIGINT, signal.SIGTERM}


@contextmanager
def deferred_signals():
    # Linux: deliver pending caught signals only after ownership/cleanup is ready.
    previous = signal.pthread_sigmask(signal.SIG_BLOCK, HANDLED_SIGNALS)
    try:
        yield
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, previous)



def safe_path(root):
    path = Path(root)
    support = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))
    if (not path.is_absolute() or '..' in path.parts or path.resolve() != path or
        not path.is_relative_to(Path('/tmp')) or path == Path('/tmp') or
        path.is_relative_to(health.REPO) or path.is_relative_to(support.resolve())):
        raise health.Refusal('invalid_root', 2)
    return path


@contextmanager
def source_root(root, token):
    path = safe_path(root)
    if not token or len(token) > 4096:
        raise health.Refusal('invalid_root', 2)
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:]:
            nxt = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = nxt
        health.owned(os.fstat(fd), directory=True)
        if stat.S_IMODE(os.fstat(fd).st_mode) != 0o700:
            raise health.Refusal('invalid_root', 2)
        marker = health.contract()[3]
        if (health.read_file(fd, marker, 4096) != token.encode() or
            health.read_file(fd, '.lifeos-synthetic-root', 128) != health.SYNTHETIC_MARKER):
            raise health.Refusal('invalid_root', 2)
        yield fd
    finally:
        os.close(fd)


class Destination:
    """Only this instance can remove its exclusively created root, never recursively."""
    def __init__(self, root, token):
        self.path = safe_path(root)
        if (self.path.parent != Path('/tmp') or
            not self.path.name.startswith('lifeos-recovery-') or not token or len(token) > 4096):
            raise health.Refusal('invalid_root', 2)
        self.fd = None
        self.published = False
        self.identity = None
        try:
            with deferred_signals():
                # mkdir acquires ownership; never adopt an existing path.
                os.mkdir(self.path, 0o700)
                self.identity = self.path.lstat()
                self.fd = os.open(self.path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
                opened = os.fstat(self.fd)
                if (opened.st_dev, opened.st_ino) != (self.identity.st_dev, self.identity.st_ino):
                    raise health.Refusal('invalid_root', 2)
            self.write(health.contract()[3], token.encode())
            self.write('.lifeos-synthetic-root', health.SYNTHETIC_MARKER)
        except BaseException:
            self.close()
            raise

    def write(self, name, data):
        fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=self.fd)
        with os.fdopen(fd, 'wb') as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())

    def close(self):
        # Cleanup must finish before another caught signal can be delivered.
        with deferred_signals():
            try:
                if self.identity is None or self.published:
                    return
                current = self.path.lstat()
                if (current.st_dev, current.st_ino) != (self.identity.st_dev, self.identity.st_ino):
                    return
                if self.fd is None:
                    # open failed before markers existed: remove only the same empty root.
                    os.rmdir(self.path)
                    return
                opened = os.stat('.', dir_fd=self.fd, follow_symlinks=False)
                if (opened.st_dev, opened.st_ino) != (self.identity.st_dev, self.identity.st_ino):
                    return
                filename, marker = health.contract()[2:]
                allowed = {filename, marker, '.lifeos-synthetic-root', MANIFEST,
                           *(filename + suffix for suffix in ('-wal', '-shm', '-journal'))}
                names = os.listdir(self.fd)
                # Unexpected entries or links mean ownership assumptions no longer hold.
                if not set(names) <= allowed:
                    return
                for name in names:
                    health.owned(os.stat(name, dir_fd=self.fd, follow_symlinks=False))
                for name in names:
                    os.unlink(name, dir_fd=self.fd)
                os.rmdir(self.path)
            finally:
                if self.fd is not None:
                    os.close(self.fd)
                    self.fd = None
                self.identity = None


def record_digest(connection):
    """All stored values, including history; no row content is emitted."""
    digest = hashlib.sha256()
    names = [r[0] for r in connection.execute(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
    for name in names:
        quoted = '"' + name.replace('"', '""') + '"'
        # Sort encoded rows so the fingerprint is independent of physical page order.
        rows = []
        for row in connection.execute('SELECT * FROM ' + quoted):
            rows.append(json.dumps([{'blob': v.hex()} if isinstance(v, bytes) else v
                                    for v in row], separators=(',', ':'), ensure_ascii=True))
        digest.update(json.dumps([name, sorted(rows)], separators=(',', ':')).encode())
    return digest.hexdigest()


def file_digest(fd, filename):
    data = health.read_file(fd, filename, health.MAX_BYTES)
    return hashlib.sha256(data).hexdigest()


def transfer(operation, root, token, destination, destination_token, *, progress_hook=None):
    if operation not in ('backup', 'restore'):
        raise health.Refusal('invalid_arguments', 2)
    app, version, filename, _ = health.contract()
    deadline = time.monotonic() + 5
    with source_root(root, token) as fd:
        checked = os.stat(filename, dir_fd=fd, follow_symlinks=False)
        health.owned(checked)
        if checked.st_size > health.MAX_BYTES:
            raise health.Refusal('unavailable', 4)
        for suffix in ('-wal', '-shm', '-journal'):
            try:
                sidecar = os.stat(filename + suffix, dir_fd=fd, follow_symlinks=False)
            except FileNotFoundError:
                continue
            health.owned(sidecar)
            if operation == 'restore' or sidecar.st_size > health.MAX_BYTES:
                raise health.Refusal('unavailable', 4)
        manifest = None
        if operation == 'restore':
            try:
                manifest = json.loads(health.read_file(fd, MANIFEST, 4096))
            except (ValueError, UnicodeError):
                raise health.Refusal('invalid_snapshot', 5) from None
            if (not isinstance(manifest, dict) or manifest.get('format_version') != 1 or
                manifest.get('database_sha256') != file_digest(fd, filename)):
                raise health.Refusal('invalid_snapshot', 5)
        # Pin the directory for the lifetime of SQLite and its WAL/SHM lookups.
        uri = Path(f'/proc/self/fd/{fd}/{filename}').as_uri() + '?mode=ro'
        with closing(sqlite3.connect(uri, uri=True, timeout=0.1)) as source:
            current = os.stat(filename, dir_fd=fd, follow_symlinks=False)
            if (checked.st_dev, checked.st_ino) != (current.st_dev, current.st_ino):
                raise health.Refusal('invalid_root', 2)
            source.execute('PRAGMA trusted_schema=OFF')
            source.execute('PRAGMA query_only=ON')
            source.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
            # Establish one read snapshot for both logical digest and backup, including WAL.
            source.execute('BEGIN')
            if (source.execute('PRAGMA application_id').fetchone()[0] != app or
                source.execute('PRAGMA user_version').fetchone()[0] != version):
                raise health.Refusal('incompatible', 3)
            page_size = source.execute('PRAGMA page_size').fetchone()[0]
            if source.execute('PRAGMA page_count').fetchone()[0] * page_size > health.MAX_BYTES:
                raise health.Refusal('unavailable', 4)
            expected = record_digest(source)
            if manifest is not None and manifest.get('records_sha256') != expected:
                raise health.Refusal('invalid_snapshot', 5)
            target = None
            try:
                # Include constructor return/assignment in the protected lifetime.
                with deferred_signals():
                    target = Destination(destination, destination_token)
                target.write(filename, b'')
                with closing(sqlite3.connect(str(target.path / filename), timeout=0.1)) as output:
                    def progress(status, remaining, total):
                        if time.monotonic() > deadline or total * page_size > health.MAX_BYTES:
                            raise health.Refusal('unavailable', 4)
                        if progress_hook:
                            progress_hook(status, remaining, total)
                    source.backup(output, pages=64, progress=progress, sleep=0.01)
                    output.execute('PRAGMA journal_mode=DELETE')
                    if record_digest(output) != expected:
                        raise health.Refusal('invalid_snapshot', 5)
                report, code = health.diagnose(str(target.path), destination_token)
                if code:
                    raise health.Refusal(report['status'], code)
                target.write(MANIFEST, json.dumps({
                    'format_version': 1, 'database_sha256': file_digest(target.fd, filename),
                    'records_sha256': expected}, sort_keys=True).encode())
                os.fsync(target.fd)
                target.published = True
                return {'format_version': 1, 'status': 'verified', 'operation': operation,
                        'identity': report['identity'], 'schema': report['schema'],
                        'integrity': report['integrity'], 'foreign_keys': report['foreign_keys'],
                        'records_match': True}, 0
            finally:
                if target is not None:
                    target.close()


def main(argv=None):
    def interrupted(signum, frame):
        raise health.Refusal('interrupted' if signum != signal.SIGALRM else 'unavailable',
                             6 if signum != signal.SIGALRM else 4)
    previous = {sig: signal.signal(sig, interrupted)
                for sig in (signal.SIGALRM, signal.SIGINT, signal.SIGTERM)}
    signal.alarm(10)
    try:
        parser = health.Parser(description=__doc__)
        parser.add_argument('operation', choices=('backup', 'restore'))
        parser.add_argument('--root', required=True)
        parser.add_argument('--marker-token', required=True)
        parser.add_argument('--destination', required=True)
        parser.add_argument('--destination-token', required=True)
        args = parser.parse_args(argv)
        result, code = transfer(args.operation, args.root, args.marker_token,
                                args.destination, args.destination_token)
    except health.Refusal as exc:
        result, code = {'format_version': 1, 'status': exc.status}, exc.code
    except FileExistsError:
        result, code = {'format_version': 1, 'status': 'destination_exists'}, 2
    except FileNotFoundError:
        result, code = {'format_version': 1, 'status': 'unavailable'}, 4
    except ValueError:
        result, code = {'format_version': 1, 'status': 'invalid_root'}, 2
    except OSError as exc:
        code = 2 if exc.errno in (errno.ELOOP, errno.ENOTDIR, errno.EINVAL) else 4
        result = {'format_version': 1, 'status': 'invalid_root' if code == 2 else 'unavailable'}
    except sqlite3.Error as exc:
        primary = getattr(exc, 'sqlite_errorcode', 0) & 255
        code = 4 if primary in (sqlite3.SQLITE_BUSY, sqlite3.SQLITE_LOCKED, sqlite3.SQLITE_INTERRUPT,
                               sqlite3.SQLITE_CANTOPEN, sqlite3.SQLITE_IOERR, sqlite3.SQLITE_FULL) else 5
        result = {'format_version': 1, 'status': 'unavailable' if code == 4 else 'unhealthy'}
    except Exception:
        result, code = {'format_version': 1, 'status': 'unavailable'}, 4
    finally:
        signal.alarm(0)
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    print(json.dumps(result, sort_keys=True, separators=(',', ':')))
    return code


if __name__ == '__main__':
    sys.exit(main())
