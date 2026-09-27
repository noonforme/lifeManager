import shutil
import subprocess
from pathlib import Path

import pytest


@pytest.mark.parametrize("errors,fragment,expected", [(True, "", "errors"), (False, "#shift-inspector", "heading"), (False, "", "none")])
def test_workspace_focus_enhancement(errors, fragment, expected):
    node = shutil.which("node")
    if not node:
        pytest.skip("Node unavailable for optional JavaScript behavior check")
    script = Path("static/js/lifeos.js").read_text()
    harness = f"""
    let focused = 'none';
    const target = name => ({{setAttribute() {{}}, focus() {{focused = name}}}});
    const errors = {str(errors).lower()} ? target('errors') : null;
    global.localStorage = {{getItem() {{throw Error('blocked')}}, setItem() {{throw Error('blocked')}}}};
    global.location = {{hash: {fragment!r}}};
    global.document = {{
      documentElement: {{removeAttribute() {{}}, setAttribute() {{}}}},
      querySelectorAll() {{return []}},
      querySelector(selector) {{
        if (selector === '.shift-inspector .error-summary') return errors;
        if (selector === '#shift-inspector-heading') return target('heading');
        return null;
      }}
    }};
    {script}
    if (focused !== {expected!r}) throw Error('Expected {expected}, got ' + focused);
    """
    result = subprocess.run([node, "-e", harness], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
