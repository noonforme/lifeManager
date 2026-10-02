# Bundled fonts

Every face is bundled with its licence in its own folder. Nothing is fetched
at run time.

| Folder | Family | Used by | Licence |
|---|---|---|---|
| `archivo/` | Archivo | Office Machine interface text | SIL Open Font License 1.1 (`archivo/OFL.txt`) |
| `azeret_mono/` | Azeret Mono | Office Machine figures | SIL Open Font License 1.1 (`azeret_mono/OFL.txt`) |
| `noto_sans/` | Noto Sans | Millennium interface text and figures | SIL Open Font License 1.1 (`noto_sans/OFL.txt`) |

## Millennium face (decision, 2026-10-02)

The shell spec (section 4.7) asks for a free, Tahoma-metric face, with Noto
Sans as the fallback if none passes a licence review.

- **Wine's Tahoma** (LGPL-2.1) matches the metrics, but the Wine project
  publishes it only as FontForge source. Bundling it would add a font build
  step and LGPL source obligations to the repository.
- No other free face that claims Tahoma metrics has a clear, published
  licence.

So Millennium uses **Noto Sans** (SIL OFL 1.1), regular, medium, semibold and
bold, from the Noto project's hinted TTF builds. Figures use the same face
with tabular figures.
