# Work Slice Verification — 2026-09-25

## Scope and revision

This receipt covers the first persisted Work vertical slice through commit `24ee14a`, plus the documentation reconciliation committed with this receipt. The slice provides validated Shift persistence; exact Decimal salary calculations; month selection and reconciliation; server-rendered create, canonical review, edit, confirmed hard-delete, and monthly register workflows; and a Work summary in the Daily Register. Money and Habits remain honest empty summaries.

No personal database, historical application database, or personal record was accessed. All runtime verification used a disposable database in a system temporary directory whose path was neither printed nor retained.

## Environment

| Item | Observed value |
| --- | --- |
| Date | 2026-09-25 |
| `uv` | 0.12.15 |
| Python | 3.14.0 |
| Django | 6.1.1 |
| pytest | 9.1.1 |

The previously established execution baseline was `uv sync --frozen --group test` followed by `uv run pytest -q`, with 58 tests passing before Work implementation.

## Focused tests

| Command | Result |
| --- | --- |
| `uv run pytest tests/test_foundation_docs.py -q` | Exit 0; 13 passed. |
| `uv run pytest tests/work -q` | Exit 0; 93 passed. |
| `uv run pytest tests/core -q` | Exit 0; 39 passed. |

The documentation contracts were first observed failing because the maintained documents still described foundation-only behavior. After reconciliation, the focused documentation suite passed.

## Complete automated gates

| Command | Result |
| --- | --- |
| `uv run pytest -q` | Exit 0; 156 passed. |
| `uv run python manage.py check` | Exit 0; no issues, 0 silenced. |
| `uv run python manage.py check --deploy` | Exit 0; six warnings, recorded below. |
| `uv run python manage.py makemigrations --check --dry-run` | Exit 0; no changes detected. |

No tests were skipped in the reported runs.

### Deployment-check warnings

The application currently has a loopback development configuration, not an internet-facing deployment configuration. Django reported these six unsilenced warnings:

- `security.W004`: `You have not set a value for the SECURE_HSTS_SECONDS setting. If your entire site is served only over SSL, you may want to consider setting a value and enabling HTTP Strict Transport Security. Be sure to read the documentation first; enabling HSTS carelessly can cause serious, irreversible problems.`
- `security.W008`: `Your SECURE_SSL_REDIRECT setting is not set to True. Unless your site should be available over both SSL and non-SSL connections, you may want to either set this setting True or configure a load balancer or reverse-proxy server to redirect all connections to HTTPS.`
- `security.W009`: `Your SECRET_KEY has less than 50 characters, less than 5 unique characters, or it's prefixed with 'django-insecure-' indicating that it was generated automatically by Django. Please generate a long and random value, otherwise many of Django's security-critical features will be vulnerable to attack.`
- `security.W012`: `SESSION_COOKIE_SECURE is not set to True. Using a secure-only session cookie makes it more difficult for network traffic sniffers to hijack user sessions.`
- `security.W016`: `You have 'django.middleware.csrf.CsrfViewMiddleware' in your MIDDLEWARE, but you have not set CSRF_COOKIE_SECURE to True. Using a secure-only session cookie makes it more difficult for network traffic sniffers to steal the CSRF token.`
- `security.W018`: `You should not have DEBUG set to True in deployment.`

These warnings are accepted only for the loopback development configuration. Any broader deployment requires separate TLS, cookie, host, and secret settings.

## Isolated migration and startup

A command created a system temporary directory, installed an exit trap, and set `LIFEOS_DATABASE_PATH` to an absolute SQLite file beneath that directory without printing it.

1. `uv run python manage.py migrate --noinput` exited 0.
2. `uv run python manage.py runserver 127.0.0.1:8765 --noreload` started successfully.
3. `GET /ready/` returned HTTP 200 and the expected readiness marker.
4. `GET /` returned HTTP 200 and the Daily Register marker.
5. `GET /work/` returned HTTP 200 and the Work register marker.
6. `GET /work/shifts/new/` returned HTTP 200 and the New shift marker.
7. The exit trap stopped the server and deleted the temporary directory.

An initial root-page probe used an incorrectly capitalized marker and failed despite HTTP 200. Inspection established that the template's actual heading is `Daily register`; the corrected probe then passed all routes. No product code changed in response.

## Complete HTTP workflow

A separate process used Django's CSRF-enforcing client with the allowed loopback host and another disposable database. Output contained statuses and route markers only.

1. Create form: HTTP 200 with expected marker.
2. Create POST with a valid CSRF token: HTTP 302 to canonical review.
3. Canonical review: HTTP 200 with expected marker.
4. Edit POST with a fresh valid CSRF token: HTTP 302 to canonical review; the disposable record reflected the edit.
5. Delete confirmation: HTTP 200 with expected marker.
6. Delete POST with a fresh valid CSRF token: HTTP 302 to the selected month.
7. Final selected month: HTTP 200 with the empty-state marker and no remaining Shift.

The first client attempt used Django's default `testserver` host. Runtime settings correctly rejected it as outside `ALLOWED_HOSTS`; the workflow was repeated using `127.0.0.1` and passed. No host restriction was weakened.

## Source and privacy scans

Scoped scans established:

- runtime templates, CSS, and JavaScript contain no remote runtime asset reference; the only CSS URLs are repository-local font files;
- executable and configured source contains no Playwright, Selenium, Puppeteer, Cypress, browser-driver, screenshot, snapshot, golden-image, pixel-comparison, or visual-regression tooling;
- the historical absolute application path appears only in non-authoritative provenance/specification and a safety assertion, not runtime source;
- executable/configuration source contains no user-home absolute path;
- tracked state contains no SQLite/database file, collected-static directory, media/private directory, or verification-only personal-value marker.

Pre-existing untracked `.claude/`, root `PRODUCT.md`, and other files beneath `docs/superpowers/plans/` remained outside this slice's commits.

## Whole-slice review and fix pass

The requested Opus reviewer could not start because its provider quota was exhausted. A fresh fallback reviewer then examined the complete `f8f6699..62eeb7c` range, the approved spec and plan, the execution rulings, and current repository files. It reported no Critical findings, four Important findings, and two Minor findings.

The single fix pass addressed all four Important findings through regressions observed RED before implementation:

- edge-year month parameters now visibly fall back rather than raising during date or navigation construction;
- expected database failures during form constraint validation and edit/delete lookup now receive controlled responses and class-only logging;
- delete commit failure recovery retains the original identifier so its recovery page can render;
- the Daily Register derives salary and nearest-shift information from one materialized month snapshot.

The focused review regression run passed 10/10 after the fixes. Work tests passed 102/102, core tests passed 39/39, and the complete suite passed 165/165. The ordinary Django check and migration drift check passed.

The two Minor findings were deferred: current-page navigation semantics on Work pages, and enforcing GET-only behavior on the canonical detail view. Both are recorded in the execution ledger and final handoff rather than silently treated as fixed.

The reviewer declined the explicitly manual browser and assistive-technology checks, real-world tax-policy validity, internet-facing deployment security, the ledgered salary-fixture policy ruling, and runtime browser-tool execution. Those boundaries remain as documented rather than being represented as reviewed behavior.

## Visual and assistive-technology boundary

No visual browser testing occurred. No browser driver, screenshot, image snapshot, golden file, pixel comparison, capture round, or visual-regression service was used.

These seven manual checks remain **unverified**:

1. actual layout at 320 CSS pixels;
2. layout and operation at 200% browser zoom;
3. a complete text-spacing override;
4. keyboard traversal and visible focus;
5. system, light, and dark theme behavior, including blocked storage;
6. reduced-motion behavior;
7. screen-reader smoke testing of landmarks, forms, error feedback, state labels, tables, and message regions.

Semantic response tests, static asset contracts, and deterministic calculations provide useful evidence but do not close these manual gaps.
