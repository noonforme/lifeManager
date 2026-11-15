# Bundled fonts

The current application bundles the following families. Nothing is fetched at
runtime. Keep each family's license notice with its files.

| Folder | Family | Provenance and license |
| --- | --- | --- |
| `era_sans/` | EraSans, regular and bold | Wine's unmodified Tahoma-metric files, renamed in pubspec; LGPL-2.1-or-later. See [SOURCE](era_sans/SOURCE) for attribution and hashes and [LICENSE](era_sans/LICENSE) for the license text. |
| `noto_sans/` | Noto Sans, regular/medium/semibold/bold | SIL Open Font License 1.1; see [OFL.txt](noto_sans/OFL.txt). |

`pubspec.yaml` declares the active font assets and license texts;
`lib/app/font_licenses.dart` registers the notices. EraSans is the current shell
face. Earlier Office Machine/initial Millennium choices are historical design
context; Archivo and Azeret Mono are not present in this font directory.
These font licenses apply to the fonts. Application source is covered by the root LICENSE.
