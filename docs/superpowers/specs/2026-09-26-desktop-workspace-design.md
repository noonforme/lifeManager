# Desktop workspace design

## Approved intent

LifeOS becomes a desktop-first professional working tool rather than a page-oriented website. The owner approved an Operations desk direction: review a useful cross-domain overview, then work in a domain. The first implementation slice is the shared shell, overview, and one complete Work workflow with a table and adjacent inspector. VOLT is operating-model inspiration, not a visual or feature specification.

Success: the owner can review a month, select a shift, inspect or correct it beside the register, and continue in coherent monthly context. The table is the dominant content, not a large title or explanatory panel.

## Scope

Change the shared shell and overview presentation, and Work register/review/create/edit/delete composition. Money and Habits inherit shared chrome and control styling but retain their existing workflows. Preserve any unrelated changes. No new domains, charts, exports, filters, sorting, scheduling generator, salary policies, persisted fields, migrations, client framework, or data API.

## Architecture and alternatives

Chosen approach: server-rendered workspace composition using existing Work canonical endpoints. Register selection is ordinary GET navigation; form actions POST to existing mutation endpoints. The workspace renders the monthly snapshot and inspector together. Canonical URLs without workspace context retain independent record pages and existing redirect behavior.

JavaScript is permitted for progressive enhancement, including workspace focus management, unsaved-edit protection, and interaction ergonomics. It is not the main application implementation: Django owns routing, rendered records, validation, calculations, and persistence. Ordinary HTTP workflows remain functional without scripts. Do not introduce a client-managed SPA or browser-owned authoritative editor. An inspector containing only links to separate edit pages is simpler but fails the approved continuous editing workflow.

Core continues to consume immutable domain summaries. It does not import Work persistence or reproduce calculations. Work owns selection, forms, validation, transactions, and month calculations.

## Routes and working context

The register accepts an optional selected shift identifier: `/work/?month=YYYY-MM&shift=ID`. Selection resolves only within the single materialized monthly shift tuple. Missing selection shows a neutral inspector. Malformed, absent, deleted, or out-of-month identifiers do not expose another record or cause a server error; render a factual selection-unavailable state.

Existing create, detail, edit, and delete endpoints remain canonical. An explicit `workspace=1` plus strictly parsed `month=YYYY-MM` requests workspace composition at those endpoints. Only validated internal context is carried by query parameters and form actions; there is no arbitrary `next` redirect. Unknown context parameters never change authoritative mutation decisions.

Workspace detail/edit/delete operate on a record belonging to the supplied month. A stale or mismatched month redirects GET requests to the record's actual monthly workspace using canonical internal URLs. Workspace mutation requests with mismatched context return a conflict response before mutation, with a route to review the current record; users do not silently act on an unexpected context.

Successful workspace create/edit redirects to the saved record's actual month and selected identifier. If an edit changes the date to another month, the workspace follows the record and feedback states that it moved. Successful deletion returns to the deleted record's month with no selection. Cancel returns to the original validated register/selection and performs no mutation. Ordinary no-context canonical workflows retain their existing behavior.

## Work composition

A compact workspace heading identifies Work. Month navigation and New shift occupy the task toolbar. A restrained summary presents existing monthly shift count, hours, overtime, gross, deductions, and estimated net without decorative stat tiles. Essential estimate qualification remains visible; the full formula is available in a native disclosure outside the main record-reading path.

The main area consists of a dominant table and adjacent inspector. Table columns retain the existing Date, Type, Worked, Overtime, and Rate content. Numeric columns align for comparison. Each record has an ordinary selection link with an accessible name; selected state and keyboard focus are distinct. The scrollable table region is labeled and keyboard accessible. Do not require clicking an unlabelled row.

Inspector modes: no selection, review, new, edit, and delete confirmation. Review shows owned record fields and escaped notes with Edit, Delete, and canonical full-review access. Create/edit reuse the existing Shift form and field/error semantics. Delete names the affected record and uses an explicit POST confirmation rather than a browser confirm dialog.

The table remains visible during inspector forms, including validation failures. Preserve submitted safe values, associate errors with fields, and keep summary errors accessible. No live earnings preview or client calculation is added.

## Shell and overview

Persistent labeled navigation exposes Overview, Work, Money, and Habits. A compact context area accommodates theme controls without a large decorative banner. Maintain skip navigation, exactly one main landmark, existing message regions, and current-page indication.

Overview uses existing domain summaries in Work/Money/Habits order. It communicates state and entry actions without fake liveness, decorative graphs, additional queries for telemetry, or fabricated urgency. Domain unavailability remains isolated. Where practical, Work's entry link explicitly uses the same month represented by its summary.

## Visual direction

Operations desk: neutral flat panes, clear functional boundaries, readable workhorse interface typography, compact fixed heading scale, aligned figures, and restrained semantic color. Light and dark are fully supported; neither is an imitation of VOLT. Each pane owns a job. Actions belong to their affected pane; destructive actions are separated from routine operations.

Reject oversized page headings, paper-led editorial staging, neon control-room imagery, simulated IDE chrome, retro desktop graphics, ornamental cards, gauges, gratuitous clocks, and animation that does not explain a state change. Selection/hover/focus/error/success must remain distinct without relying on color alone.

Shared styles must keep Money and Habits readable and operable, including their longer forms and existing disclosures. Their markup is not rewritten as part of this slice.

## Responsive and accessibility behavior

At widths that cannot comfortably accommodate both panes, present register and inspector sequentially with clear anchors and return navigation. Inspector forms remain usable at 200% zoom and narrow widths. Keep page-level horizontal overflow absent; tables may scroll within their labeled region. Use semantic forms and controls, keyboard-accessible navigation, visible focus, sufficient contrast, text-spacing resilience, and reduced-motion support. Desktop-first does not justify tiny unreadable controls or mouse-only interactions.

The brief has no measured typical or maximum record volume. The layout must support empty, single-record, and long synthetic months without clipped content or fixed-height truncation; do not invent pagination in this slice.

## Persistence, failures, and privacy

Reuse Shift validation, Decimal calculation policy, transaction boundaries, CSRF, and Post/Redirect/Get. Salary uses exactly one materialized monthly snapshot. No migration or browser copy of persisted records is needed. Canonical review remains GET-only.

Database failures return private generic unavailable responses. Preserve operational logging without personal content or exception text. If touched mutation code needs commit-outcome recovery, follow the existing Money distinction between known failure and uncertain outcome: advise reviewing records before retrying an uncertain write rather than asserting nothing was saved.

Never inspect, copy, seed, reset, or use the personal database. Synthetic manual verification runs on an explicitly owned temporary runtime database. No personal records appear in screenshots, documentation, logs, or fixtures. No external assets or runtime CDNs are added.

## Verification and finish

Use deterministic Django tests for scoped selection, context parsing, canonical fallback, in-workspace CRUD, moved-date redirects, cancellation, stale context, invalid forms, CSRF, output escaping, GET-only review, unavailable responses, and unchanged salary behavior. Run existing Core/Work and full-suite regressions, Django checks, and migration-drift checks with owned temporary settings.

Do not introduce a visual browser-test suite: foundation engineering rules prohibit it. Manual visual inspection uses synthetic data, in one batched desktop/narrow light/dark pass, with at most one confirmation pass after fixes. Validate the shared shell against Money and Habits as well as Work. If browser capture tooling is unavailable, report the missing visual verification rather than claiming it passed.

Verify `./app.sh` still starts and tests the app, with startup directed to a disposable runtime database. Update launcher commands only if requirements changed.

Before UI edits, persist the Impeccable surface direction contract using seed `5366146a`, Operations desk, code-led, and load its craft floor. At finish, obtain the independent Impeccable finish review and document the shipped visual system in DESIGN.md and its sidecar. Existing foundation design prose is historical evidence, not authority over the approved replacement.

## Approval boundary

This spec translates the approved design brief into route and composition behavior. Application implementation follows written-spec approval and a concrete implementation plan. No commit or push is authorized by this document.
