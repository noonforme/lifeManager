# Money Slice Verification — 2026-09-25

## Scope and revision

This receipt covers the persisted Money vertical slice from specification commit `ec5b562` through whole-slice review fix revision `101d820`. It covers Transaction persistence, exact monthly movement, Money-owned month queries, server-rendered create/review/edit/delete workflows, monthly register presentation, Daily Register integration, route-identity navigation, and the final review disposition.

## Environment

- Linux `7.1.10-200.fc44.x86_64`
- Python `3.14.7`
- uv `0.12.15`
- Django `6.1.1`
- pytest `9.1.1`
- SQLite through Django's bundled backend

## Automated gates

All commands exited successfully unless a warning-only result is stated.

- `uv run pytest tests/money -q` — 147 passed, 0 failed, 0 skipped, no warnings reported.
- `uv run pytest tests/core tests/work -q` — 141 passed, 0 failed, 0 skipped, no warnings reported.
- `uv run pytest tests/test_foundation_docs.py -q` — 13 passed, 0 failed, 0 skipped, no warnings reported.
- `uv run pytest -q` — 312 passed, 0 failed, 0 skipped, no warnings reported.
- `uv run python manage.py check` — no issues, 0 silenced.
- `uv run python manage.py makemigrations --check --dry-run` — no changes detected.

`uv run python manage.py check --deploy` completed with six expected loopback-development warnings and is not represented as a production deployment pass:

- `security.W004`: `SECURE_HSTS_SECONDS` is unset.
- `security.W008`: `SECURE_SSL_REDIRECT` is not true.
- `security.W009`: the development `SECRET_KEY` is not suitable for deployment.
- `security.W012`: `SESSION_COOKIE_SECURE` is not true.
- `security.W016`: `CSRF_COOKIE_SECURE` is not true.
- `security.W018`: `DEBUG` is true.

A deployment beyond the loopback development boundary requires separate production security settings.

## Owned disposable migration and startup

An operating-system temporary directory and an absolute SQLite path beneath it were created for this check and removed by an exit trap. No path was printed or retained.

- migrations applied successfully;
- readiness: HTTP 200, `ready` marker present;
- Daily Register: HTTP 200, `Daily register` marker present;
- Work register: HTTP 200, `Work register` marker present;
- Money register: HTTP 200, `Money register` marker present;
- new transaction form: HTTP 200, `New transaction` marker present.

## CSRF-enforced HTTP workflow

A separate owned disposable absolute database was migrated. Django's test client used `enforce_csrf_checks=True` and host `127.0.0.1`. Tokens, submitted values, record identifiers, and database paths were not printed.

- create GET — 200, form marker present;
- create POST — 302, canonical detail redirect;
- detail GET — 200, review marker present;
- edit GET — 200, form marker present;
- edit POST — 302, same canonical detail redirect;
- delete confirmation GET — 200;
- delete POST — 302, selected-month redirect;
- selected-month GET — 200, honest empty-state marker present and no Transaction remained.

## Privacy, dependency, and tracked-state scans

- Runtime remote-reference scan found only local font licence attribution URLs and the intentional loopback-only `CSRF_TRUSTED_ORIGINS`; no remote runtime asset dependency was found.
- Prohibited visual-tool scan matched the domain word `snapshot` only in one-snapshot calculation/query names and tests; it found no browser driver, screenshot, golden image, pixel-comparison, capture-round, or visual-regression tooling.
- Historical-reference scan found only the maintained non-normative provenance statement in `LESSONS.md` and its documentation contract; no executable historical-source reference was found. The historical application directory was not scanned or accessed.
- Database-artifact scan found no `.sqlite3`, `.sqlite`, or `.db` file in the repository.
- No personal home path was found in executable or configured source.
- Unrelated untracked `.claude/`, root `PRODUCT.md`, and `docs/superpowers/plans/` remained unstaged and untouched.
- The staged product change will contain only maintained documentation, its contract test, and this receipt.

## Review disposition

The final whole-slice review was a separate self-review because the approved execution direction was **no agents for now**. This is weaker than a fresh independent reviewer and is not represented as equivalent evidence.

The review checked the specification, implementation plan review focus, ledger rulings, maintained foundation documents, migration, Money source and templates, integration boundaries, tests, and this receipt. It found no Critical finding and no deferred Minor finding.

One Important finding was accepted: direct create/edit save failures and direct delete failures displayed uncertain-commit recovery guidance even though the exception occurred inside the atomic block and Django rolled the operation back. Uncertainty should be reserved for a failure raised while exiting the atomic block after the mutation returned. Regression assertions were written first and observed failing for all three mutation types. Revision `101d820` moves the completion marker until after `save()` or `delete()` returns, preserving uncertain-outcome guidance for atomic-exit failures while omitting it for definite direct failures.

Focused RED–GREEN evidence:

- direct create save failure, direct edit save failure, and direct delete failure — 3 expected failures before the correction;
- those three direct-failure tests plus the three atomic-exit tests — 6 passed after the correction;
- Money suite — 147 passed;
- affected Core and Work suites — 141 passed;
- foundation documentation contracts — 13 passed;
- complete suite — 312 passed.

Because the correction touched mutation views, the owned disposable migration/startup and complete CSRF-enforced HTTP workflow were repeated after the fix with the results recorded above. No second review was dispatched.

## Skipped and unverified checks

No visual browser test, screenshot, snapshot image, golden image, pixel comparison, capture round, or visual-regression service was used.

The following require a person using an actual browser or assistive technology and remain **unverified**:

1. actual layout at 320 CSS pixels;
2. layout and operation at 200% browser zoom;
3. a complete text-spacing override;
4. keyboard traversal and visible focus;
5. system, light, and dark theme behavior, including blocked storage;
6. reduced-motion behavior;
7. screen-reader smoke testing of landmarks, forms, error feedback, state labels, transaction tables, navigation current-page semantics, and message regions.
