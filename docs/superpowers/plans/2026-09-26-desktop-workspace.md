# Desktop Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task if Native execution is selected, or superpowers:subagent-driven-development if that method is selected. Steps use checkbox syntax for tracking.

**Goal:** Replace page-oriented presentation with an Operations desk shell, actionable overview, and a complete Work table/inspector workflow.

**Architecture:** Django renders the monthly snapshot and inspector together using existing canonical routes. Workspace context is validated on the server; existing forms, salary calculations, transactions, and canonical fallback flows remain authoritative. JavaScript may enhance focus and edit ergonomics but is not the main application.

**Tech Stack:** Python 3.14, Django, SQLite, Django templates/forms, local CSS and optional progressive JavaScript, pytest.

**Spec:** docs/superpowers/specs/2026-09-26-desktop-workspace-design.md

## Global Constraints

- JavaScript is permitted for progressive enhancement, including workspace focus management, unsaved-edit protection, and interaction ergonomics.
- Django owns routing, rendered records, validation, calculations, and persistence. Ordinary HTTP workflows remain functional without scripts.
- No new domains, charts, exports, filters, sorting, scheduling generator, salary policies, persisted fields, migrations, client framework, or data API.
- Money and Habits inherit shared chrome and control styling but retain their existing workflows. Preserve unrelated changes.
- Never inspect, copy, seed, reset, or use the personal database. Synthetic manual verification uses an explicitly owned temporary runtime database.
- No external assets or runtime CDNs are added. No visual browser-test suite is introduced.
- No commits or pushes are authorized. Work in the current workspace; do not create another worktree.
- Verify ./app.sh still starts and tests the app using safe temporary data.

## Review Focus

1. A record's date changes month during editing: successful save follows its actual month, and stale context cannot mutate an unexpected record.
2. Inspector form validation mutates an in-memory model instance: monthly totals and table values must still reflect persisted records, not invalid submitted data.
3. Selected IDs are malformed, huge, deleted, or from another month: no extra record disclosure, integer conversion crash, or server failure.
4. A database error occurs after a mutation may have committed: feedback must recommend inspecting records rather than blindly repeating the write.
5. A narrow viewport, long note, or high zoom meets the shared shell: no clipped forms, unreachable actions, or page-level horizontal overflow; Money/Habits remain operable.

---

## File responsibilities

- lifeos/work/views.py: HTTP orchestration, context validation, mutation dispatch, redirects and private recovery.
- lifeos/work/workspace.py (new): validated workspace context, internal URL construction, materialized register presentation context. No persistence mutation or salary-policy changes.
- templates/base.html and templates/core/dashboard.html: shared application chrome and overview composition.
- templates/work/register.html: month toolbar, summary and two-pane workspace composition.
- templates/work/_shift_table.html (new): record selection and numeric comparison.
- templates/work/_shift_inspector.html (new): review/new/edit/delete/neutral states.
- templates/work/_shift_form.html: existing labeled field and validation rendering, reused rather than duplicated.
- templates/work/shift_form.html, shift_detail.html, shift_confirm_delete.html: retain standalone canonical fallbacks.
- static/css/app.css: replacement shared visual system and responsive Work panes; preserve Money/Habits usability.
- static/js/lifeos.js: existing theme enhancement; add only bounded workspace focus behavior if needed.
- lifeos/work/summary.py: explicit month on overview Work entry link.
- tests/work/test_workspace.py (new): workspace behavior, boundaries, CRUD and regression scenarios.
- tests/core/test_dashboard.py and tests/core/test_assets.py: shared shell and approved enhancement contracts.
- DESIGN.md and .impeccable/design.json: document finished system through the Impeccable handoff.

## Task 1: Workspace context and selected-record review

**Interfaces:** A new workspace module exposes `workspace_month(request: HttpRequest, *, today: date) -> Month | None`, accepting only workspace=1 with valid strict month context; `register_url(month: Month, shift_id: int | None = None) -> str`; and `workspace_url(route: str, month: Month, *, pk: int | None = None) -> str`. Use the existing Month type in lifeos/work/queries.py, not a parallel calendar implementation. Monthly rendering materializes shifts once and calculates salary from that same tuple.

- [ ] Read lifeos/work/queries.py, forms.py, views.py, tests/work/test_queries.py, and test_register.py before editing. Preserve tests' monkeypatch boundary for shifts_for_month or update that boundary deliberately with equivalent failure coverage.
- [ ] Add tests for neutral selection, selected same-month review, foreign-month privacy, malformed/huge selection, stable ordering, and one clock read. Initial test shape:

```python
from datetime import date
from decimal import Decimal
import pytest
from django.urls import reverse
from lifeos.work.models import Shift

pytestmark = pytest.mark.django_db

def make_shift(day, note='synthetic workspace note'):
    return Shift.objects.create(work_date=day, shift_type='normal',
        worked_hours=Decimal('8.00'), overtime_hours=Decimal('1.00'),
        hourly_rate=Decimal('20.00'), note=note)

def test_workspace_selected_record_is_month_scoped(client):
    shift = make_shift(date(2026, 8, 31), note='foreign-month-marker')
    response = client.get(reverse('work:register'),
        {'month': '2026-09', 'shift': str(shift.pk)})
    assert response.status_code == 200
    assert 'foreign-month-marker' not in response.content.decode()
    assert response.context['selected_shift'] is None

@pytest.mark.parametrize('selection', ['bad', '-1', '9' * 5000])
def test_invalid_selection_is_safe(client, selection):
    response = client.get(reverse('work:register'),
        {'month': '2026-09', 'shift': selection})
    assert response.status_code == 200
    assert response.context['selected_shift'] is None
```

- [ ] Run `uv run pytest tests/work/test_workspace.py -q`; confirm the new context assertions fail before implementation.
- [ ] Implement strict context helpers and register selection against the materialized tuple only. Compare bounded canonical ID strings rather than converting unlimited user input to int. Use reverse plus urlencode for internal URLs. Keep default/month-error behavior intact.
- [ ] Render explicit selected-row and neutral/selection-unavailable inspector states. Include canonical detail links so existing register link/order assertions remain valid without private notes leaking into unselected rows.
- [ ] Run `uv run pytest tests/work/test_workspace.py tests/work/test_register.py tests/work/test_queries.py -q` and resolve failures without weakening privacy or salary assertions.

## Task 2: Complete in-workspace CRUD and canonical compatibility

**Interfaces:** Existing create/detail/edit/delete endpoints accept valid workspace context and render the register composition with `inspector_mode` equal to new/review/edit/delete. Existing standalone responses remain default without valid workspace context. Shared render orchestration must read persisted monthly records before binding/validating the edit form, or query fresh instances after validation, so ModelForm changes cannot contaminate the table snapshot.

- [ ] Read existing create/detail/edit/delete tests, money/views.py recovery semantics, and all Work canonical templates.
- [ ] Add failing tests using the `make_shift` helper from Task 1 for GET create/edit/delete workspace composition and POST success. Use concrete valid payload:

```python
payload = {'work_date': '2026-09-26', 'shift_type': 'normal',
    'worked_hours': '8.00', 'overtime_hours': '1.00',
    'hourly_rate': '20.00', 'note': 'synthetic edited note'}
url = reverse('work:shift-edit', args=[shift.pk]) + '?workspace=1&month=2026-09'
response = client.post(url, payload)
assert response.status_code == 302
assert response.url == reverse('work:register') + f'?month=2026-09&shift={shift.pk}'
```

- [ ] Add moved-date test with work_date=2026-10-01 expecting month=2026-10, stale-context POST expecting 409 and no database mutation, GET stale-context redirect to actual context, and invalid month/context falling back safely to canonical behavior.
- [ ] Add validation test with worked_hours='invalid': response retains a table, form errors, escaped submitted note, and original persisted summary values. Add CSRF enforced-client test, cancel links as GET-only non-mutating navigation, detail POST returning 405, and HTML note escaping.
- [ ] Run `uv run pytest tests/work/test_workspace.py -q`; confirm failures identify missing composition/continuity behavior.
- [ ] Extract table and inspector partials. Reuse _shift_form.html field semantics and provide explicit form action, cancel URL, mode heading, record identity, and delete confirmation. Do not wrap forms in another form.
- [ ] Add composition to existing views, retaining no-context redirect and template behavior. Validate context before mutation; capture original month before ModelForm validation; preserve successful date-change context and messages. Add private detail lookup recovery and GET-only decorator.
- [ ] Add commit-outcome tests following Money's existing test approach: simulate DatabaseError before save versus on transaction exit. Implement truthful recovery feedback; no exception text or private record fields enter logs.
- [ ] Run `uv run pytest tests/work -q`, retaining all salary fixture tests and existing canonical workflow regressions.

## Task 3: Operations desk shell, overview and Work presentation

**Interfaces:** Existing summary presentation values remain unchanged except Work's action URL explicitly includes its summarized month. Base shell provides one main landmark, shared polite/assertive feedback, labeled navigation and theme controls. Work layout classes own two-pane composition without domain logic in CSS or JS.

- [ ] Read Core dashboard/templates/tests, asset tests, shared script, Money/Habits templates, and foundation accessibility requirements. Read Impeccable craft-floor immediately before UI edits.
- [ ] Persist the approved surface direction contract for templates/work/register.html with related base/dashboard targets, seed 5366146a, Operations desk, and code-led path. Do not rewrite DESIGN.md before the built system is reviewed.
- [ ] Add shell/overview regression tests: one main and h1, current-page labels, theme controls, isolated unavailable summary, explicit Work month URL. Preserve semantic hooks required by existing tests.
- [ ] Add render tests for table's labeled focusable scroll region, selected row identity, disclosure for full salary policy, actual header/summary values, form labels/errors, and accessible narrow-flow links. Add long escaped note and a synthetic long month to ensure complete server output without truncation.
- [ ] Run `uv run pytest tests/core tests/work -q` and record new failures.
- [ ] Replace shared tokens and layout with neutral light/dark work surfaces, compact fixed heading scale, consistent controls, semantic selection/error/focus, and clear pane boundaries. Keep local fonts or use system UI faces; no new remote font downloads. Avoid global control shrinking that violates foundation target requirements.
- [ ] Reshape overview using existing immutable summaries. Reshape Work toolbar, compact totals and table/inspector composition; keep formula disclosure and tax qualification truthful. Money/Habits markup remains unchanged.
- [ ] Add optional local progressive enhancement only where it improves the actual workflow: for example focus the inspector heading after a selected-record navigation and the error summary after invalid submission, with a visible focus target and no required fetch or client state. Do not install an SPA library. If existing asset tests prohibit all domain-aware JS, update them to assert the corrected boundary (no authoritative calculations, persistence, external requests or browser record cache), not a blanket JavaScript prohibition.
- [ ] Run `uv run pytest tests/core tests/work tests/money tests/habits -q`. Fix shared CSS/markup contract regressions rather than rewriting unrelated domain workflows.

## Task 4: Verification, independent review and documentation

**Interfaces:** All prior tasks are complete. Only owned temporary databases may be used by checks and launcher startup. No visual test dependency is added.

- [ ] Run `uv run pytest -q`, preserving bootstrap ownership safeguards. Run checks through project test settings with the bootstrap's owned database configuration, not default runtime settings that resolve personal data paths. Read bootstrap/test settings before choosing exact invocation.
- [ ] Inspect available browser/capture capability once. If available, launch a temporary loopback runtime with synthetic Work records covering empty/long month and inspector modes. Inspect desktop and narrow, light and dark, plus Money and Habits shell compatibility in one batch. If unavailable, explicitly report visual inspection as blocked.
- [ ] Fix material defects from this batch together, then perform at most one confirmation batch. No open-ended micro-polish.
- [ ] Verify launcher tests with `uv run pytest tests/test_app_script.py -q`. Exercise ./app.sh test option and startup option against an explicitly owned disposable runtime database; terminate the server after readiness and verify no changes to launcher requirements are needed. Do not delete uninspected pre-existing directories.
- [ ] Run Impeccable detector once on changed UI targets when no design hook covers this run. Fix mechanical findings and forward remaining findings to the independent reviewer.
- [ ] Spawn Impeccable finish reviewer with approved spec/contract, changed paths, actual screenshots when available, tests/check results and disclosed limitations. Respond only to its material findings within bounded review rounds. Do not claim visual approval if screenshots were unavailable.
- [ ] Spawn documenter to derive root DESIGN.md and .impeccable/design.json from the finished implementation. Keep current foundation architecture/product constraints; document JavaScript as optional enhancement rather than main application code. Record verification and remaining limitations in docs/verification/2026-09-26-desktop-workspace.md.
- [ ] Show final diff/status. Report what works, exact test outcomes, launcher verification, independent-review scope, and any unverified visual behavior. Do not commit or push.

## Plan self-review

Spec coverage: Tasks 1–2 cover context and continuous CRUD; Task 3 covers shell, overview, replacement visual world, accessibility and permitted enhancement; Task 4 covers safe verification, launcher, review and documentation. Each Review Focus condition has an owning test/inspection step. No persisted schema, new feature roadmap, or client-main architecture is introduced.
