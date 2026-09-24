import hashlib
from pathlib import Path

import pytest
from django.test import Client

pytestmark = pytest.mark.django_db
ROOT = Path(__file__).parents[2]
FONT_HASHES = {
    "barlow-latin-400-normal.woff2": "7c9c80a6c32c0619d61c28f28723e68c5f8f75163e77ee5cf64c39e640e0d71e",
    "barlow-latin-500-normal.woff2": "7c0597b1b0c771139c958982210f05b275993037f0f3ba20d7a9300a0741dc80",
    "barlow-latin-600-normal.woff2": "2b14e8397d552f351a4396dec25ec5da1348865683100e94c4ab0faea4a9a254",
    "jetbrains-mono-latin-400-normal.woff2": "14425ba9c695763c1547f48a206b7aa60350a33ae23de09f0407877f3fcd89eb",
    "jetbrains-mono-latin-500-normal.woff2": "cb182feeed4d798ff6961d3c79f7026279448fca0676438aaecb21f3fc39553a",
    "jetbrains-mono-latin-600-normal.woff2": "400c6bfda18d5d14acad1c15d6dcb9f8e13c015e7286317e0b9a482539bef147",
}


def test_font_assets_match_pinned_hashes() -> None:
    for name, expected in FONT_HASHES.items():
        assert hashlib.sha256((ROOT / "static/fonts" / name).read_bytes()).hexdigest() == expected


def test_shell_uses_local_progressive_assets(client: Client) -> None:
    html = client.get("/").content.decode()
    assert '/static/css/app.css' in html
    assert '/static/js/lifeos.js' in html
    assert "http://" not in html and "https://" not in html
    assert "onclick=" not in html
    assert "<details" in html and "<summary" in html
    for theme in ("system", "light", "dark"):
        assert f'data-theme-choice="{theme}"' in html
    assert html.count('aria-pressed="') == 3
    assert "<noscript>" in html
    assert "System theme and navigation remain available" in html


def test_theme_script_stays_non_authoritative() -> None:
    script = (ROOT / "static/js/lifeos.js").read_text().lower()
    for forbidden in ("fetch(", "xmlhttprequest", "salary", "momentum", "mutation"):
        assert forbidden not in script
    assert "localstorage" in script
