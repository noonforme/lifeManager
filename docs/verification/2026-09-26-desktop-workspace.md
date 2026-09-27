# Desktop workspace verification

Date: 2026-09-27. Scope: shared Operations desk shell, Overview and Work monthly table/inspector; Money and Habits inherit shared styling without workflow changes.

## Evidence

- `uv run pytest -q`: 480 passed after the final navigation and boundary-date fixes (initial implementation run: 475 passed in 2.33s).
- Core/Work/Money/Habits task verification: 447 passed in 1.89s.
- `uv run pytest tests/test_app_script.py -q`: 4 passed.
- `git diff --check`: no whitespace errors.
- Django system check under owned disposable test settings: no issues (0 silenced).
- Migration drift under the same settings: no changes detected.
- `./app.sh` option 2: 475 passed in 2.20s.
- `./app.sh` option 1: dependencies resolved, migrations applied to a newly created explicitly owned temporary database, loopback server returned 200 for `/`, selected-month Work register, workspace New shift, Money and Habits. Process group stopped after checks. No launcher command changes required.
- Initial startup probe incorrectly compared `ready\n` with `ready` and timed out despite successful HTTP responses. Correcting probe whitespace handling produced the successful startup evidence above; no application fix was needed.

The personal database was not inspected or used. No new persistence schema, salary policy, client framework, remote assets or visual-test dependency was introduced. Changes remain uncommitted.

## Behavioral coverage

Work tests cover bounded same-month selection, malformed and huge selection, selected-note privacy, one clock read, workspace create/edit/delete/review, moved-date redirect, stale-context conflict, persisted totals during invalid ModelForm validation, CSRF, escaping and uncertain-commit advice. New presentation tests cover main/heading/current navigation semantics, keyboard-reachable table region, salary disclosure, 90 synthetic records, long escaped notes and progressive inspector/error focus with blocked theme storage.

## Limits and review state

The Impeccable hook scanned changed UI targets with no deterministic findings. This is not visual approval.

No desktop/narrow light/dark captures were inspected. The existing foundation engineering document prohibits capture tooling, while the workspace plan calls for manual captures. This conflict remains disclosed rather than silently adding browser tooling. The independent Impeccable finish reviewer returned **recapture** because desktop/mobile screenshots were absent; no visual approval or completed finish-review claim is made.

Actual 320px reflow, 200% browser zoom, full text-spacing override, keyboard traversal, system/light/dark rendered appearance, reduced-motion behavior and screen-reader smoke checks remain manual gaps. Independent source correctness review confirmed one Important issue: table selection and month navigation used query-only links, which preserved the edit/create endpoint rather than returning to the register. The links now use the canonical register path. `test_workspace_edit_table_links_return_to_register` was observed failing then passing; the complete suite subsequently passed 476 tests. Review also identified saved records in years 0001/9999 redirecting to unsupported monthly context. These valid canonical records now redirect to full record review rather than a misleading fallback month; four create/edit boundary cases were observed RED→GREEN. Final full suite: 480 passed. Root DESIGN.md and .impeccable/design.json describe the code-derived Operations desk system, separately from visual approval.
