# Habits slice verification

Date: 2026-09-26. Branch: feat/habits-slice. Changes remain uncommitted.

## Automated evidence

- `uv run pytest tests/habits -q`: 109 passed after the review fix pass.
- `uv run pytest -q`: 425 passed after the review fix pass.
- Launcher/documentation focused tests: 17 passed.
- Django system checks with owned disposable test settings: no issues.
- Migration drift check with owned disposable test settings: no changes detected.
- All Habits migrations applied successfully to an owned disposable database.
- Real `./app.sh` startup with disposable test settings: readiness and root/Habits/create HTTP routes passed.
- Real `./app.sh` test menu: complete suite passed.
- CSRF-enforced disposable synthetic workflow: habit create/review/edit, occurrence create/review/edit/remove, archive/restore passed.
- Initial runtime workflow used the Django client's default host and failed the existing host restriction; corrected the verification client to the allowed loopback host and reran successfully. No application host policy was weakened.
- Habits cross-domain/remote-runtime/forbidden-tooling source scan: passed.
- Source database artifact scan: passed.
- `git diff --check`: passed.

No personal database or historical application/data was accessed. Runtime verification used explicitly owned disposable test settings and stopped its process group afterward. No visual/browser tooling was introduced.

## Manual gaps

Not performed: actual 320 CSS-pixel layout; 200% browser zoom; full text-spacing override; keyboard traversal/visible focus; system/light/dark themes with blocked storage; reduced-motion behavior; screen-reader smoke testing.

## Review

Fresh independent whole-slice review completed with no Critical findings. The single TDD fix pass addressed selected-date entry, actionable history links, duplicate-date correction guidance, separately paginated history (20 per page), compact lifetime metric loading, range-filtered projection evidence, interval database constraints, direct-save typed evidence/component validation, and private recovery for malformed persisted schedules. Full tests, checks, migration application, real launcher startup/test menu and CSRF workflow were rerun successfully afterward.

Ruling: exact lifetime streak/momentum computation still reads compact date/result/value evidence proportional to lifetime history; it is not falsely described as constant-memory or range-truncated. Register rows carry no detailed history; detail notes/reasons are fetched only for the selected page; projection evidence is filtered to its requested range.

Ruling: relational component presence cannot be enforced by a same-row SQLite check during a multi-row configuration transaction. HTTP configuration validates the complete schedule; direct component saves reject irrelevant kinds, and malformed persisted schedules produce private unavailable responses instead of unhandled ValueError. Bulk writes/raw SQL are not validated save boundaries and must preserve domain invariants.

The alleged HTTP post-trim length issue was disproved by a passing regression: Django form character fields trim before length validation. Deferred Minor: repeated archive/restore is an idempotent no-op but its success message does not distinguish an already matching state.

The review did not independently rerun the coordinator’s gates or perform manual accessibility checks. Fresh coordinator gate evidence above covers automation; manual gaps remain explicitly open.
