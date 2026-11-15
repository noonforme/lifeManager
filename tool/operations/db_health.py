#!/usr/bin/env python3
"""Offline, synthetic-only SQLite diagnostics. Never opens source with SQLite."""
import argparse
from contextlib import closing
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import sqlite3
import stat
import sys
import time

REPO = Path(__file__).resolve().parents[2]
SYNTHETIC_MARKER = b'lifeos-synthetic-only-v1\n'
MAX_BYTES = 128 * 1024 * 1024


class Refusal(Exception):
    def __init__(self, status, code):
        self.status, self.code = status, code


def contract():
    base = REPO / 'lib/core/database'
    def value(file, pattern):
        return re.search(pattern, (base / file).read_text()).group(1)
    return (int(value('database_identity.dart', r'lifeOsApplicationId = (0x[0-9A-F]+)'), 16),
            int(value('schema_versions.dart', r'currentSchemaVersion = (\d+)')),
            value('database_location.dart', r"databaseFilename = '([^']+)'"),
            value('test_root_guard.dart', r"markerName = '([^']+)'"))


def owned(st, directory=False):
    if (st.st_uid != os.getuid() or
        not (stat.S_ISDIR(st.st_mode) if directory else stat.S_ISREG(st.st_mode)) or
        st.st_mode & 0o022 or (not directory and st.st_nlink != 1)):
        raise Refusal('invalid_root', 2)


def read_file(root_fd, name, limit):
    fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=root_fd)
    try:
        owned(os.fstat(fd))
        data = os.read(fd, limit + 1)
        if len(data) > limit:
            raise Refusal('invalid_root', 2)
        return data
    finally:
        os.close(fd)


def guarded_image(root, token, filename, marker):
    path = Path(root)
    support = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))
    # Same repository/production exclusions as Dart, with a narrower Linux lab scope.
    if (not path.is_absolute() or '..' in path.parts or path == Path('/') or
        path.resolve() != path or path.is_relative_to(REPO) or
        path.is_relative_to(support.resolve()) or
        not path.is_relative_to(Path('/tmp')) or not token or len(token) > 4096):
        raise Refusal('invalid_root', 2)
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:]:
            nxt = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = nxt
        owned(os.fstat(fd), directory=True)
        if stat.S_IMODE(os.fstat(fd).st_mode) != 0o700:
            raise Refusal('invalid_root', 2)
        if (read_file(fd, marker, 4096) != token.encode() or
            read_file(fd, '.lifeos-synthetic-root', 128) != SYNTHETIC_MARKER):
            raise Refusal('invalid_root', 2)
        # Inspect all sidecars without following or opening links.
        def no_sidecars():
            for suffix in ('-wal', '-shm', '-journal'):
                try:
                    owned(os.stat(filename + suffix, dir_fd=fd, follow_symlinks=False))
                except FileNotFoundError:
                    continue
                raise Refusal('unavailable', 4)
        no_sidecars()
        try:
            checked = os.stat(filename, dir_fd=fd, follow_symlinks=False)
            owned(checked)
            db = os.open(filename, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        except FileNotFoundError:
            raise Refusal('unavailable', 4) from None
        try:
            before = os.fstat(db)
            owned(before)
            if (checked.st_dev, checked.st_ino) != (before.st_dev, before.st_ino):
                raise Refusal('invalid_root', 2)
            if before.st_size > MAX_BYTES:
                raise Refusal('unavailable', 4)
            # SQLite's pending + shared locking bytes: nonblocking, no lock waits.
            try:
                fcntl.lockf(db, fcntl.LOCK_SH | fcntl.LOCK_NB, 512, 0x40000000)
            except OSError:
                raise Refusal('unavailable', 4) from None
            no_sidecars()
            chunks = []
            remaining = MAX_BYTES + 1
            while remaining:
                chunk = os.read(db, min(1024 * 1024, remaining))
                if not chunk:
                    break
                chunks.append(chunk)
                remaining -= len(chunk)
            after = os.fstat(db)
            current = os.stat(filename, dir_fd=fd, follow_symlinks=False)
            if ((before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) !=
                (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns) or
                (current.st_dev, current.st_ino) != (before.st_dev, before.st_ino)):
                raise Refusal('unavailable', 4)
            no_sidecars()
            return b''.join(chunks)
        finally:
            os.close(db)
    finally:
        os.close(fd)


def diagnose(root, token):
    app_id, version, filename, marker = contract()
    image = guarded_image(root, token, filename, marker)
    result = {'format_version': 1, 'status': 'unhealthy', 'identity': None,
              'schema': None, 'integrity': None, 'foreign_keys': None, 'settings': None}
    if len(image) < 100 or image[:16] != b'SQLite format 3\x00':
        return result, 5
    # A checkpointed WAL database has no sidecars but retains WAL header flags.
    journal = 'wal' if image[18:20] == b'\x02\x02' else 'delete'
    image = image[:18] + b'\x01\x01' + image[20:]
    with closing(sqlite3.connect(':memory:', timeout=0)) as connection:
        deadline = time.monotonic() + 4
        connection.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
        connection.deserialize(image)
        connection.execute('PRAGMA trusted_schema=OFF')
        connection.execute('PRAGMA foreign_keys=ON')
        connection.execute('PRAGMA query_only=ON')
        connection.execute('PRAGMA busy_timeout=0')
        actual_id = connection.execute('PRAGMA application_id').fetchone()[0]
        actual_version = connection.execute('PRAGMA user_version').fetchone()[0]
        # Never echo unknown database-supplied values into shared output.
        result['identity'] = {'matches': actual_id == app_id}
        result['schema'] = {'current_version': version, 'matches': actual_version == version,
                            'structure_matches': False}
        if actual_id != app_id or actual_version != version:
            result['status'] = 'incompatible'
            return result, 3
        schema = json.loads((REPO / f'drift_schemas/schema_v{version}.json').read_text())
        types = {'int': 'INTEGER', 'bool': 'INTEGER', 'string': 'TEXT',
                 'dateTime': 'INTEGER', 'blob': 'BLOB', 'real': 'REAL'}
        expected = {e['data']['name']: e['data'] for e in schema['entities']
                    if e['type'] == 'table'}
        actual = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        structure = actual - {'sqlite_sequence'} == set(expected)
        for name, table in expected.items():
            columns = table['columns']
            pk = table.get('explicit_pk', [])
            metadata = []
            expected_fk = set()
            for column in columns:
                col = column['name']
                auto = 'auto-increment' in column['dsl_features']
                metadata.append((col, types[column['moor_type']], int(not column['nullable']),
                                 1 if auto else pk.index(col) + 1 if col in pk else 0))
                for feature in column['dsl_features']:
                    if isinstance(feature, dict) and 'foreign_key' in feature:
                        fk = feature['foreign_key']
                        expected_fk.add((fk['to']['table'], col, fk['to']['column'],
                                         (fk['on_update'] or 'NO ACTION').upper(),
                                         (fk['on_delete'] or 'NO ACTION').upper()))
            for constraint in table['constraints']:
                match = re.fullmatch(r'FOREIGN KEY \(([^)]+)\) REFERENCES (\w+) \(([^)]+)\) ON DELETE (\w+)', constraint)
                if match:
                    src, target, dst, action = match.groups()
                    expected_fk.update((target, left.strip(), right.strip(), 'NO ACTION', action)
                                       for left, right in zip(src.split(','), dst.split(',')))
            rows = connection.execute('PRAGMA table_info("' + name + '")').fetchall()
            actual_metadata = [(r[1], r[2], r[3], r[5]) for r in rows]
            actual_fk = {tuple(r[2:7]) for r in connection.execute('PRAGMA foreign_key_list("' + name + '")')}
            structure = structure and metadata == actual_metadata and expected_fk == actual_fk
        result['schema']['structure_matches'] = structure
        result['settings'] = {'source_journal_mode': journal, 'diagnostic_foreign_keys': True,
                              'diagnostic_busy_timeout_ms': 0, 'diagnostic_query_only': True,
                              'diagnostic_synchronous': connection.execute('PRAGMA synchronous').fetchone()[0],
                              'page_size': connection.execute('PRAGMA page_size').fetchone()[0],
                              'application_expected_synchronous': 'full',
                              'application_expected_busy_timeout_ms': 5000}
        if not structure:
            result['status'] = 'incompatible'
            return result, 3
        integrity = all(row == ('ok',) for row in connection.execute('PRAGMA integrity_check'))
        violations = sum(1 for _ in connection.execute('PRAGMA foreign_key_check'))
        result['integrity'] = {'ok': integrity}
        result['foreign_keys'] = {'violation_count': violations}
        result['status'] = 'healthy' if integrity and not violations else 'unhealthy'
        return result, 0 if result['status'] == 'healthy' else 5


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Refusal('invalid_arguments', 2)


def main(argv=None):
    def deadline(signum, frame):
        raise Refusal('unavailable', 4)
    signal.signal(signal.SIGALRM, deadline)
    signal.alarm(5)
    try:
        parser = Parser(description=__doc__)
        parser.add_argument('--root', required=True)
        parser.add_argument('--marker-token', required=True)
        args = parser.parse_args(argv)
        result, code = diagnose(args.root, args.marker_token)
    except Refusal as exc:
        result, code = {'format_version': 1, 'status': exc.status}, exc.code
    except (OSError, ValueError):
        result, code = {'format_version': 1, 'status': 'invalid_root'}, 2
    except sqlite3.Error:
        result, code = {'format_version': 1, 'status': 'unhealthy'}, 5
    except Exception:
        result, code = {'format_version': 1, 'status': 'unavailable'}, 4
    finally:
        signal.alarm(0)
    result = {**dict.fromkeys(('identity', 'schema', 'integrity', 'foreign_keys', 'settings')), **result}
    print(json.dumps(result, sort_keys=True, separators=(',', ':')))
    return code


if __name__ == '__main__':
    sys.exit(main())
