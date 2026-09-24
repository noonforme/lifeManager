# Milestone One Verification — 2026-09-25

## Scope and revision

The automated and startup gates exercised commit `9ac78ca02cc4638516d1e26b0c86123be4625ec0` plus the documented reconciliation below. The resulting verification commit adds this receipt, the salary-rate clarification, and its contract test. Milestone scope remains the Django foundation and empty Daily Register; Work, Money, and Habits persistence is not implemented.

## Environment recreation

| Command | Result |
| --- | --- |
| `rm -rf .venv` | Exit 0; removed only the ignored project environment. |
| `uv sync --frozen --group test` | Exit 0; recreated Python 3.14 environment from `uv.lock`, installing 9 packages. |
| `uv run python -c "import django; print(django.get_version())"` | Exit 0; printed `6.1.1`. |

## Automated gates

All counts below are exact; no tests were skipped.

| Command | Result |
| --- | --- |
| `uv run pytest tests/test_settings.py -q` | Exit 0; 9 passed. |
| `uv run pytest tests/core -q` | Exit 0; 32 passed. |
| `uv run pytest tests/test_foundation_docs.py -q` | Exit 0; 9 passed before reconciliation. |
| `uv run pytest -q` | Exit 0; 50 passed before reconciliation. |
| `uv run python manage.py check` | Exit 0; no issues, 0 silenced. |
| `uv run python manage.py check --deploy` | Exit 0 with 6 warnings, recorded below. |
| `uv run python manage.py makemigrations --check --dry-run` | Exit 0; no changes detected. |
| `uv run python manage.py collectstatic --noinput --clear` | Exit 0; 10 static files copied to ignored `staticfiles/`. |

### Deployment-check warnings

The development configuration intentionally binds to loopback HTTP and is not a deployable internet-facing configuration. Django reported these unsilenced warnings:

- `security.W004`: `SECURE_HSTS_SECONDS` is unset.
- `security.W008`: `SECURE_SSL_REDIRECT` is not `True`.
- `security.W009`: the development `SECRET_KEY` is short/insecure.
- `security.W012`: `SESSION_COOKIE_SECURE` is not `True`.
- `security.W016`: `CSRF_COOKIE_SECURE` is not `True`.
- `security.W018`: `DEBUG` is `True`.

These are accepted only for the current loopback development milestone. Any non-loopback deployment requires separate TLS, cookie, host, and secret settings.

## Isolated startup proof

A system temporary directory created with `mktemp` held an absolute `LIFEOS_DATABASE_PATH`; no default or personal database path was evaluated or probed. The temporary root path was not recorded. On port 8765:

1. `uv run python manage.py migrate` exited 0 against the throwaway database.
2. `uv run python manage.py runserver 127.0.0.1:8765 --noreload` started successfully.
3. `GET /ready/` returned HTTP 200 with body `ready`.
4. `GET /` returned HTTP 200 and contained `Daily register`, `Work`, `Money`, and `Habits`.
5. The server was stopped and the temporary directory deleted by the command's exit trap.

## Source-level checks

The successful scoped scan found:

- no remote URLs in runtime templates, CSS, or JavaScript;
- no HTMX, Playwright, Selenium, pixel-diff, or screenshot-API tooling in executable/configured source;
- no inline event handlers in templates;
- the historical absolute path only in provenance/specification/test assertions, with the normative foundation mention confined to `LESSONS.md`;
- no SQLite file, `staticfiles/`, `.venv/`, or historical source artifact in `git status`.

Two exploratory scan commands exited non-zero before the successful check. The first had a shell-quoting syntax error. The second searched every file under `static/` for any HTTP URL and correctly found attribution URLs in the two bundled font licence texts; the check was narrowed to runtime templates, CSS, and JavaScript because licence attribution is not a remote runtime dependency. No product source was changed to conceal those results.

Untracked pre-existing `.claude/`, root `PRODUCT.md`, and `docs/superpowers/plans/` remained untouched and outside milestone commits.

## Documentation reconciliation

Verification found that `DOMAIN.md` named GPM, VSD, and PSD but did not state the exact rates already evidenced by the portable salary cases. A new contract test, `test_domain_defines_exact_salary_rates`, was observed failing. `DOMAIN.md` now states GPM 20%, VSD 12.52%, PSD 6.98%, per-output half-up rounding, total-tax summation, and net derivation.

| Command | Result |
| --- | --- |
| `uv run pytest tests/test_foundation_docs.py::test_domain_defines_exact_salary_rates -q` (RED) | Exit 1; 1 failed because the rates were absent. |
| Same focused command after documentation correction | Exit 0; 1 passed. |
| `uv run pytest -q` after reconciliation | Exit 0; 51 passed, no skips. |

## Visual and assistive-technology boundary

No visual browser tests were run by design. Milestone one contains no browser driver, screenshots, golden images, pixel comparisons, capture rounds, or visual-regression service.

The following manual gaps remain **unverified**:

- actual layout at 320 CSS pixels;
- layout and operation at 200% browser zoom;
- complete text-spacing override in a browser;
- keyboard traversal and visible focus in a browser;
- system/light/dark theme behavior in a browser, including blocked storage;
- reduced-motion behavior in a browser;
- screen-reader smoke testing of landmarks, disclosure, state labels, and message regions.

Static semantic, contrast, local-asset, and non-authoritative-script tests reduce but do not close these manual gaps.
