from hashlib import sha256
from pathlib import Path
from tempfile import NamedTemporaryFile
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "static" / "fonts"
BASE = "https://cdn.jsdelivr.net/npm"
FILES = {
    "barlow-latin-400-normal.woff2": (f"{BASE}/@fontsource/barlow@5.1.1/files/barlow-latin-400-normal.woff2", "7c9c80a6c32c0619d61c28f28723e68c5f8f75163e77ee5cf64c39e640e0d71e"),
    "barlow-latin-500-normal.woff2": (f"{BASE}/@fontsource/barlow@5.1.1/files/barlow-latin-500-normal.woff2", "7c0597b1b0c771139c958982210f05b275993037f0f3ba20d7a9300a0741dc80"),
    "barlow-latin-600-normal.woff2": (f"{BASE}/@fontsource/barlow@5.1.1/files/barlow-latin-600-normal.woff2", "2b14e8397d552f351a4396dec25ec5da1348865683100e94c4ab0faea4a9a254"),
    "jetbrains-mono-latin-400-normal.woff2": (f"{BASE}/@fontsource/jetbrains-mono@5.1.1/files/jetbrains-mono-latin-400-normal.woff2", "14425ba9c695763c1547f48a206b7aa60350a33ae23de09f0407877f3fcd89eb"),
    "jetbrains-mono-latin-500-normal.woff2": (f"{BASE}/@fontsource/jetbrains-mono@5.1.1/files/jetbrains-mono-latin-500-normal.woff2", "cb182feeed4d798ff6961d3c79f7026279448fca0676438aaecb21f3fc39553a"),
    "jetbrains-mono-latin-600-normal.woff2": (f"{BASE}/@fontsource/jetbrains-mono@5.1.1/files/jetbrains-mono-latin-600-normal.woff2", "400c6bfda18d5d14acad1c15d6dcb9f8e13c015e7286317e0b9a482539bef147"),
    "BARLOW-LICENSE.txt": (f"{BASE}/@fontsource/barlow@5.1.1/LICENSE", "10b0e6bb43166a50fbe7cde2895bd7f703738a5da843acb5c97c95dc9ea26817"),
    "JETBRAINS-MONO-LICENSE.txt": (f"{BASE}/@fontsource/jetbrains-mono@5.1.1/LICENSE", "bb1c26eb6fe1839e3759548777c8a35b9495ce4878a4b833b1b63d43ff313a4b"),
}


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for name, (url, expected) in FILES.items():
        data = urlopen(url, timeout=30).read()
        actual = sha256(data).hexdigest()
        if actual != expected:
            raise RuntimeError(f"Hash mismatch for {name}: {actual}")
        with NamedTemporaryFile(dir=DESTINATION, delete=False) as temporary:
            temporary.write(data)
            temporary_path = Path(temporary.name)
        temporary_path.replace(DESTINATION / name)
        print(f"verified {name}")


if __name__ == "__main__":
    main()
