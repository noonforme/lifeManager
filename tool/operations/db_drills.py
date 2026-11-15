#!/usr/bin/env python3
"""Deterministic synthetic-only incident exercises; no user-supplied data paths."""
import argparse
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile

import db_health as health


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def diagnose(root, token, expected):
    result = subprocess.run(
        [str(health.REPO / 'tool/operations/db-health.sh'), '--root', str(root),
         '--marker-token', token], capture_output=True, text=True, timeout=7)
    report = json.loads(result.stdout)
    require(result.returncode == expected, 'unexpected diagnostic exit code')
    require(not result.stderr, 'unexpected diagnostic stderr')
    require(str(root) not in result.stdout and token not in result.stdout,
            'diagnostic leaked lab identifiers')
    return {'exit_code': result.returncode, 'report': report}


def run(drill):
    # No root argument: only this invocation's exclusively acquired temporary tree.
    with tempfile.TemporaryDirectory(prefix='lifeos-drill-', dir='/tmp') as directory:
        root = Path(directory)
        os.chmod(root, 0o700)
        identity = root.stat()
        token = 'synthetic-incident-drill'
        app, version, filename, marker = health.contract()
        (root / marker).write_text(token)
        (root / '.lifeos-synthetic-root').write_bytes(health.SYNTHETIC_MARKER)
        db = root / filename
        with closing(sqlite3.connect(db)) as connection:
            connection.executescript(
                (health.REPO / 'test/core/database/fixtures/schema_v3.sql').read_text())
            for table in ('desk_tiles', 'desks', 'saved_views'):
                connection.execute('DROP TABLE ' + table)
            connection.execute(f'PRAGMA application_id={app}')
            connection.execute(f'PRAGMA user_version={version}')
            connection.execute("INSERT INTO preferences VALUES ('appearance', 'night')")
            connection.commit()
        baseline = db.read_bytes()
        healthy = diagnose(root, token, 0)
        if drill == 'lock':
            with closing(sqlite3.connect(db, timeout=0)) as writer:
                # Rollback journal locking, no writes/sidecars: health sees a real
                # cross-process exclusive lock, rather than the WAL-sidecar guard.
                writer.execute('BEGIN EXCLUSIVE')
                unhealthy = diagnose(root, token, 4)
                writer.rollback()
            require(db.read_bytes() == baseline, 'lock drill modified database')
            recovery = 'Release the lab exclusive transaction with ROLLBACK and close its connection.'
        elif drill == 'schema':
            with closing(sqlite3.connect(db)) as connection:
                connection.execute(f'PRAGMA user_version={version + 100}')
            fault_image = db.read_bytes()
            unhealthy = diagnose(root, token, 3)
            require(db.read_bytes() == fault_image, 'diagnostics changed incompatible database')
            # This is replacement of our injected header, not a down-migration.
            db.write_bytes(baseline)
            recovery = 'Replace the closed lab file with its exact pre-injection image; no down-migration.'
        else:
            # Deterministic unavailable path even under root: a missing file,
            # not chmod (which privileged processes can bypass), disk filling,
            # or an unmount affecting other applications.
            offline = root / 'offline.sqlite'
            db.rename(offline)
            unhealthy = diagnose(root, token, 4)
            require(not db.exists(), 'diagnostic created unavailable database')
            require(offline.read_bytes() == baseline, 'offline image modified')
            offline.rename(db)
            recovery = 'Move the held lab image back to its expected filename.'
        verified = diagnose(root, token, 0)
        require(db.read_bytes() == baseline, 'recovery changed baseline bytes')
        with closing(sqlite3.connect(db)) as connection:
            require(connection.execute('SELECT value FROM preferences WHERE key=?',
                                       ('appearance',)).fetchone() == ('night',),
                    'synthetic record lost')
        current = root.stat()
        require((identity.st_dev, identity.st_ino) == (current.st_dev, current.st_ino),
                'lab root identity changed')
        report = {
            'drill': drill, 'scope': 'synthetic laboratory only',
            'symptoms': {'lock': 'Offline health check cannot acquire a shared read lock.',
                         'schema': 'Database identity matches but version is unsupported.',
                         'storage': 'Expected database file is unavailable.'}[drill],
            'hypothesis': {'lock': 'Another connection holds an exclusive rollback-journal lock.',
                           'schema': 'A newer or incompatible database was selected.',
                           'storage': 'The lab storage path no longer contains its database.'}[drill],
            'evidence': {'baseline': healthy, 'fault': unhealthy, 'recovered': verified},
            'diagnosis': {'lock': 'Held BEGIN EXCLUSIVE produces exit 4; releasing it restores exit 0.',
                          'schema': 'Only the injected future version produces exit 3; source stays unchanged.',
                          'storage': 'Removing only the owned filename produces exit 4 without creating a file.'}[drill],
            'recovery': recovery,
            'verification': {'baseline_bytes_preserved': True, 'synthetic_record_preserved': True,
                             'database_sha256': hashlib.sha256(baseline).hexdigest()},
            'prevention': {'lock': 'Keep write transactions short; close app normally before offline diagnostics; never delete sidecars to bypass refusal.',
                           'schema': 'Check schema compatibility before upgrade; keep verified backups and use a compatible application.',
                           'storage': 'Check storage availability and path ownership before startup; retain verified backups.'}[drill],
        }
    require(not root.exists(), 'owned lab cleanup failed')
    report['cleanup'] = 'Only the newly created temporary lab root was removed.'
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('drill', choices=('lock', 'schema', 'storage'))
    args = parser.parse_args()
    # Assertions propagate nonzero: logging an expected failure is not a pass.
    print(json.dumps(run(args.drill), sort_keys=True, indent=2))


if __name__ == '__main__':
    main()
