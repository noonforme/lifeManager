import os
import tempfile
import uuid
from pathlib import Path

_TEST_ROOT = Path(tempfile.mkdtemp(prefix="lifeos-tests-")).resolve()
_TEST_OWNER = str(uuid.uuid4())
(_TEST_ROOT / ".lifeos-test-root").write_text(_TEST_OWNER)
os.environ.setdefault("LIFEOS_TEST_ROOT", str(_TEST_ROOT))
os.environ.setdefault("LIFEOS_TEST_OWNER", _TEST_OWNER)
os.environ.setdefault("LIFEOS_TEST_DATABASE_PATH", str(_TEST_ROOT / "test.sqlite3"))
