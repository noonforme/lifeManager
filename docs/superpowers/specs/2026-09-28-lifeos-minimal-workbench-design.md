# LifeOS minimal workbench redesign

## Approved intent

LifeOS becomes a minimalist, data-dense personal life-management operating environment. It is desktop-first, mouse-first, and utility-driven. The opening surface helps one trusted owner run the current day from truthful Work, Money, and Habits records. It is not a decorative dashboard, a set of old pages inside new chrome, or a generic SaaS card grid.

The product mechanism is reconciliation: compare intended or expected life with recorded life, expose the discrepancy, and make the smallest useful correction. The first viewport must put real records, derived values, exceptions, and actions into one continuous working field.

Success means the owner can open LifeOS, identify what requires attention, select a factual item, inspect its context and derivation, act without losing surrounding context, and use the same operating grammar across Work, Money, and Habits.

## Scope

This redesign replaces the user-facing dashboard and the complete Work, Money, and Habits interaction model. It introduces:

- a React workbench application;
- a Django JSON API backed by the existing domain services and SQLite records;
- an actionable cross-domain Today register;
- a universal select-and-inspect workbench for all three shipped domains;
- locally bundled React-Bootstrap and compiled Bootstrap Sass as the UI foundation;
- shared client routing, server-state queries, inspector forms, menus, filters, temporal navigation, and pane preferences;
- automated frontend, API, and browser-level verification;
- a deliberate migration away from superseded user-facing Django templates and the monolithic incumbent stylesheet.

This slice does not add a task manager, calendar UI, notes system, knowledge domain, cloud synchronization, accounts, public sharing, collaboration, telemetry, bank imports, budgets, forecasts, tax calculations, notifications, plugin systems, or mobile-native clients. It does not fabricate empty UI for unimplemented domains.

The existing Work, Money, and Habits data meanings remain authoritative. This is a product and frontend architecture replacement, not permission to change salary policy, money semantics, recurrence semantics, evidence truth, or archive history.

## Product architecture

### Chosen approach

LifeOS uses a React workbench backed by a purpose-built Django API. React owns the interactive operating experience. Django owns persistence, validation, calculations, transactions, timezone/date interpretation, stable identity, and domain invariants.

The application remains a local modular monolith. The frontend is a separately built package in the same repository and is served locally by Django for the integrated application. Development may run a frontend development server with hot reload and API proxying. Runtime pages must not depend on a CDN or third-party service.

### Alternatives rejected

A server-rendered Django interface with Bootstrap JavaScript is cheaper to migrate but cannot provide the continuous, fast desktop workbench this redesign requires. HTMX with focused JavaScript improves page transitions but would retain server-fragment composition as the primary interface model and make rich cross-domain client state awkward. A windowed desktop metaphor adds window management without improving reconciliation. Separate visual redesigns for each domain would repeat the present failure: shared chrome over incompatible workflows.

### Boundaries

Core owns:

- the application shell and frontend entry point;
- Today composition;
- shared API response conventions;
- the cross-domain actionable-item contract;
- one captured temporal context per request;
- shared workbench components and presentation contracts.

Work, Money, and Habits continue to own:

- models and persistence access;
- input validation;
- calculations and derivations;
- query semantics;
- mutation services and transaction boundaries;
- domain-specific API adaptation.

The frontend never reproduces authoritative salary, movement, recurrence, streak, momentum, attention, or evidence calculations. SQLite remains the sole source of persisted truth. Derived values are recomputed and labeled rather than persisted as competing totals.

## Repository and delivery shape

The intended shape is:

```text
frontend/
  src/
    app/
    api/
    components/
    workbench/
    domains/
      today/
      work/
      money/
      habits/
    styles/
  tests/
lifeos/
  api/
  core/
  work/
  money/
  habits/
```

The exact JavaScript package manager and build tool are implementation-plan decisions, selected for dependable local development and production builds. The plan must pin dependencies and keep the integrated startup path straightforward.

`app.sh` must be updated if commands or requirements change. At completion it must check or install the required Python and frontend dependencies according to project convention, run backend and frontend checks/tests, build frontend assets, and start the integrated application on loopback using a disposable test database for verification.

## Universal workbench

### Continuous frame

Every primary surface uses the same three-region desktop frame:

1. **System rail** — Today, Work, Money, and Habits with a clear current subsystem.
2. **Active register** — temporal scope, filters, search where justified, creation action, and dense factual records.
3. **Inspector** — the selected record, source facts, derived values, validation state, and contextual actions.

This is a contiguous workspace, not a field of floating cards. The register remains visible while the inspector reviews, creates, edits, validates, or confirms deletion. The inspector has a stable width and may use a draggable splitter. It can collapse when register width is more useful. Pane width, collapsed state, density, and theme may be remembered locally as interface preferences; they are not application records.

### Mouse-first interaction

The defining interaction is **select → inspect → act**:

- a single click selects a row or operational item;
- selection does not navigate away from or replace the register;
- the adjacent inspector updates immediately;
- double-click may enter edit mode only where unambiguous and non-destructive;
- toolbar actions apply to the current register or current selection;
- row overflow menus may expose secondary actions;
- right-click menus may enhance operation but are never the only route;
- drag-and-drop exists only where the underlying order has domain meaning;
- ordinary selection never triggers surprising navigation or mutation.

The interface is optimized for pointer precision and high information density, but complete keyboard operation, visible focus, and semantic accessibility remain mandatory.

### Inspector modes

Every domain uses consistent inspector modes:

- no selection;
- inspect;
- create;
- edit;
- validation failure;
- stale or unavailable selection;
- destructive confirmation;
- uncertain mutation outcome where applicable.

Facts appear before derived values. Edit controls are visually distinct from read-only derivations. Primary, cancel, and destructive actions stay in predictable positions. Delete confirmation names the exact record and consequence without using a browser confirmation dialog.

### State vocabulary

Selectable rows and items distinguish:

- default;
- hover;
- selected;
- keyboard focus;
- pending attention;
- unavailable;
- validation failure;
- recently saved.

State uses text, weight, fill, control availability, and accessible semantics; color never acts alone. Recently saved feedback is restrained and temporary, not gamified.

## Today command center

Today is a cross-domain operational register, not a KPI overview. It answers:

1. What requires attention?
2. What has changed?
3. What can be acted on now?

The central register is grouped by operational state:

- **Needs action** — missing records, due habits, invalid or incomplete entries, unavailable derivations, and unresolved corrections;
- **Today** — confirmed shifts, transactions, and habit outcomes for the active date;
- **Recent** — newly changed records that may warrant review.

Each row contains only decision-relevant information: domain, record or action, effective date/time, factual state, concise derived value, reason for inclusion, and available primary action. Empty sections disappear rather than consuming space with motivational copy.

Selecting an item opens its factual context in the same inspector used by its domain. Acting from Today uses the owning domain's validation and mutation service. Entering a domain from Today preserves the exact record and temporal scope represented by the selected item.

### Actionable-item contract

Core composes immutable domain adapters into a typed actionable-item response. Each item can represent:

- stable item and record identity;
- owning domain;
- temporal context;
- factual state;
- concise derived display;
- attention reason;
- permitted primary action;
- inspector resource or route;
- unavailable/error state;
- record version or modification marker where conflict handling needs one.

Core does not import domain models or reproduce domain calculations. One request captures the effective date/time once and passes it to all domain adapters. A domain failure is isolated and represented truthfully without failing the entire Today response.

## Domain workbenches

### Work

Work remains month-oriented. The register presents dense shift rows with date, start/end, break, worked duration, overtime, rate context, and estimated pay where supported. Month navigation, shift count, hours, gross, deductions, and estimated net live in the register toolbar or compact aligned summary region rather than detached metric cards.

Single-click selection opens the shift inspector. Creation, correction, and deletion use the same inspector position. Estimated salary is visibly derived and retains its existing qualification and formula. Saving preserves or follows the saved record's actual month and restores its selection. Stale, deleted, malformed, or out-of-scope selections produce explicit inspector states rather than accidental disclosure or surprising redirects.

### Money

Money becomes a continuous monthly transaction workbench. The register presents date, description, type, amount, and only model-supported context. Selected-month inflow, outflow, and net movement appear as compact inspectable derivations in the temporal toolbar. The product must continue to say selected-month movement and must not imply balance, budget, forecast, tax result, or bank synchronization.

Selecting a transaction opens its factual record and actions in the inspector. New income or expense, edit, validation failure, and destructive confirmation remain adjacent to the ledger. Ordinary operation no longer ejects the user into standalone form pages.

### Habits

Habits is organized around dated evidence. The active date is explicit and survives register loading, selection, inspection, correction, and domain transitions. Rows expose due state, factual outcome, type-relevant quantity or evidence, streak/momentum context, and attention state without implying success from missing evidence.

Check, quantity, abstinence, and scheduled-chore habits share one row and inspector grammar while retaining type-specific controls and recurrence meaning. Selecting a historical item keeps the selected historical date. Recording, correcting, and removing evidence occurs in the inspector.

Habit configuration moves into a distinct **Definitions** mode. Definition forms reveal controls relevant to the chosen habit type and recurrence model instead of permanently exposing every configuration field. Archive and restore remain explicit lifecycle operations, and archived periods preserve history.

The implementation plan must address the current lifetime-evidence loading pattern so the data-dense register remains responsive as history grows. Optimization must preserve recurrence and evidence truth.

## Frontend architecture

### Routing and URL state

Client-side routing covers Today, Work, Money, and Habits. Domain, temporal scope, filters that change the viewed record set, selected record, inspector mode where safe, and Definitions mode are URL-addressable where practical. Reloading or sharing a local URL restores the same inspectable context without encoding personal record content into the URL.

The frontend must never silently substitute the current date when a historical date was requested. This fixes the current Money/Habits temporal discontinuity and the Habit detail path that loses selected-day context.

### Server state

TanStack Query, or an equivalently capable query/cache layer selected in planning, manages server state. Cache keys include domain and temporal context. Mutations invalidate or patch only affected resources. Reversible optimistic presentation is allowed, but a record appears confirmed only after server acceptance. Failed optimistic transitions roll back visibly.

Ordinary React state owns transient interface concerns such as selection before URL synchronization, inspector mode, open menus, splitter drag state, and unsaved form drafts. A global client store is not introduced unless URL state, component state, and the query cache demonstrably cannot model a cross-cutting requirement.

### API client and error model

A typed frontend API layer normalizes successful resources, validation errors, conflicts, unavailable calculations, and unexpected failures. The UI has explicit initial-loading, background-refresh, empty, stale, rollback, domain-unavailable, and bundle-recovery states. A failed frontend bundle produces a useful recovery page rather than a blank screen.

## Django API

The API is purpose-built for the workbench rather than a mechanical exposure of database models. Initial resource families include:

- `/api/today`;
- `/api/work/shifts` and shift-specific mutations;
- `/api/money/transactions` and transaction-specific mutations;
- `/api/habits/register`;
- `/api/habits/definitions`;
- habit occurrence and lifecycle mutations;
- metadata required for valid choices, filters, and server-derived previews.

Exact URL shape, HTTP method conventions, pagination, serializer technology, CSRF strategy, and versioning are implementation-plan decisions. The design requires:

- explicit date/month request parameters;
- machine-readable and human-readable validation errors;
- clear separation of persisted facts and derived values;
- stable identity;
- action availability where server rules affect it;
- conflict information based on record versions or modification markers where concurrent/stale writes matter;
- transactional mutation semantics;
- no personal content in logs or error telemetry.

Django services used by existing views should be extracted or reused behind API endpoints rather than duplicating business rules. API tests must prove equivalence with current domain behavior before old presentation routes are removed.

## UI foundation and visual system

### Bootstrap foundation

LifeOS uses locally bundled React-Bootstrap for appropriate accessible primitives and Bootstrap Sass for tokens, utilities, and component foundations. Bootstrap supplies controls, validation semantics, dropdowns, disclosures, button groups, toolbars, and responsive helpers. It does not determine product composition or visual identity.

LifeOS-owned semantic components include:

- `WorkbenchShell`;
- `SystemRail`;
- `RegisterToolbar`;
- `DataRegister`;
- `InspectorPane`;
- `InspectorForm`;
- `SelectionSummary`;
- `TemporalNavigator`;
- `OperationalState`;
- `DestructiveConfirmation`.

Templates and components must not become opaque walls of framework utilities. Domain features compose LifeOS components, and LifeOS components wrap framework primitives. This keeps domain workflows understandable and limits framework coupling.

### Minimal precision workbench

The selected visual direction is a stripped precision workbench: exact alignment and measured state without literal instrument, retro-computer, darkroom, cockpit, or operating-system cosplay.

- quiet contiguous surfaces replace floating cards;
- one-pixel separators and aligned column boundaries establish structure;
- compact toolbars place temporal scope, filters, and creation actions together;
- practical UI typography carries prose and controls;
- tabular numerals carry dates, times, durations, quantities, and money;
- headings remain compact and stable;
- controls are pointer-efficient rather than enlarged for tablet aesthetics;
- corners are square or minimally softened;
- neutrals carry structure;
- one interaction color marks focus and selection;
- domain color appears only where identification is useful;
- error and destructive color are semantic and restrained;
- no decorative shadows, gradients, glass, glow, floating-card field, oversized hero copy, ornamental charts, or generic KPI tile row;
- icons support visible labels rather than replacing important text.

The memorable composition is the continuous rail/register/inspector workspace. The visual system should recede during sustained daily use.

### Charts and visualization

No chart belongs on Today by default. A chart may be introduced only when a specific domain workflow demonstrates that it improves a recurring decision more than a compact table, comparison, or textual derivation. Any future chart work must follow the project's visualization design process and preserve inspectable source values.

## Responsive and accessibility behavior

LifeOS is desktop-first, not desktop-only:

- wide desktop shows rail, register, and inspector simultaneously;
- constrained desktop compresses the rail and narrows the inspector before changing topology;
- narrow layouts present register and inspector sequentially with an explicit return action and preserved selection;
- table overflow remains inside the labeled register region;
- the page itself has no accidental horizontal overflow;
- density relaxes only enough for operability and never becomes an oversized card stack.

The application preserves semantic landmarks, logical focus order, visible focus, labeled controls and regions, sufficient contrast, text-spacing resilience, 200% zoom, reduced-motion behavior, and screen-reader announcements for loading, validation, save, rollback, and unavailable states. Pointer optimization does not remove keyboard access. Hover-only disclosure is prohibited for required information or actions.

Light and dark themes are equal operating environments rather than one theme being an inversion afterthought. Theme preferences are local interface preferences and do not affect record truth.

## Failures, conflicts, and privacy

- A failing domain adapter does not break Today; it yields a compact truthful unavailable state with a retry or domain-entry action.
- Invalid mutations preserve selection, temporal scope, entered values, and field-specific errors.
- Stale or deleted selections remain explained in the inspector while the register stays available.
- Conflicting writes never silently overwrite newer server state. The interface identifies the conflict and offers review/reload before retry.
- Uncertain mutation outcomes instruct the user to review current records rather than falsely asserting success or failure.
- Cancel exits edit mode without changing records or resetting register context.
- Midnight boundaries cannot make Today describe one date while an opened domain silently uses another.
- The frontend does not persist personal records into browser storage. Only non-sensitive interface preferences may be stored locally.
- Personal content must not appear in logs, readiness responses, analytics, source control, fixtures, screenshots, or documentation.
- No telemetry, advertising, remote CDN, or third-party runtime dependency is introduced.
- The development and integrated servers remain loopback-only. Deployment beyond loopback requires a separate security design.

## Migration strategy

The redesign is a deliberate replacement, not a permanent hybrid interface.

1. Establish the frontend package, integrated build, API conventions, application shell, tokens, and shared workbench primitives.
2. Implement Today using synthetic test data and real domain adapters behind tested API contracts.
3. Move Work into the universal register/inspector system and prove behavioral equivalence.
4. Move Money into the same system, including in-place CRUD and exact movement semantics.
5. Move Habits, including dated evidence, Definitions mode, lifecycle actions, and scalable queries.
6. Verify cross-domain context, accessibility, responsive behavior, production assets, and recovery states.
7. Remove superseded user-facing templates, scripts, and CSS after feature parity is proven.
8. Complete the Impeccable finish review and derive the shipped DESIGN.md and sidecar from the finished interface.

Old and new routes may coexist behind a development-only migration boundary. The shipped navigation must never expose two competing interfaces. Removal of old presentation code happens only after equivalent backend behavior and escape paths are verified.

## Testing and verification

### Backend and API

Automated Django coverage includes:

- existing domain invariants and calculations;
- Today composition and failure isolation;
- one captured temporal context per request;
- exact date/month propagation;
- historical Habit selection retaining its date;
- resource serialization and facts-versus-derived separation;
- create, update, delete, lifecycle, and evidence mutations;
- validation errors and preserved safe values;
- stale identity and write conflicts;
- transaction rollback and uncertain outcomes;
- privacy-safe error handling;
- equivalence between migrated APIs and existing domain behavior.

### Frontend

Automated frontend coverage includes:

- shell and route restoration;
- select-and-inspect behavior;
- inspector modes across all domains;
- temporal navigation and filter persistence;
- form validation and error association;
- optimistic success and visible rollback;
- loading, empty, unavailable, stale, conflict, and recovery states;
- menu and toolbar semantics;
- keyboard operation and focus restoration;
- component accessibility checks;
- pane preferences without record persistence.

### Browser workflows

Browser-level tests cover representative synthetic workflows for Today, Work, Money, and Habits, including reload restoration, historical Habit review, invalid forms, deletion confirmation, domain failure isolation, and production-built assets. Tests never read or copy the personal database.

### Rendered verification

One batched Impeccable inspection pass captures desktop and narrow layouts together, including light and dark themes as required by the surface. It exercises empty, dense, selected, editing, invalid, unavailable, conflict, and destructive-confirmation states with synthetic records. Material findings are fixed in one batch and confirmed in at most one additional build-thread capture round before the independent finish handoff.

Manual/accessibility verification includes keyboard-only use, screen-reader landmarks and announcements, 200% zoom, text-spacing overrides, reduced motion, and pointer operation at common desktop widths.

The implementation is not complete when automated tests merely pass. It must receive the independent Impeccable finish review against the approved direction contract, resolve material findings within the bounded review process, and document the shipped visual system in DESIGN.md and `.impeccable/design.json`.

After the implementation plan succeeds, `./app.sh` must still start and test the integrated application. If commands or requirements changed, it must be updated and verified with an explicitly owned disposable runtime database.

## Direction contract for implementation planning

**THESIS:** LifeOS is a minimal precision workbench where truthful records and the smallest valid correction share one continuous field. It refuses both generic card dashboards and theatrical desktop metaphors.

**OWN-WORLD:** Quiet neutral contiguous surfaces, exact one-pixel divisions, compact practical type, tabular values, pointer-efficient controls, restrained state color, and a stable rail/register/inspector topology. No floating cards, decorative charts, hardware skins, glow, glass, or oversized display copy.

**STORY:** The owner opens Today, sees factual exceptions and current records, selects one item, understands its source and derived meaning, makes the smallest useful correction, and continues without losing temporal or register context.

**FIRST VIEWPORT:** A compact labeled system rail anchors the left. The center is a dense Today register grouped into Needs action, Today, and Recent beneath one operational toolbar. A persistent inspector occupies the right, showing the selected item's facts, derivations, state, and primary action. Selection is the signature interaction; the register remains stable while the inspector changes immediately.

**FORM:** React universal workbench with Django API, code-led. Approved structural direction: Orchestrated Workspace. Approved interaction direction: select and inspect. Impeccable direction seed: `66c5219c`, assigned grounded candidate translated as Minimal Precision Workbench.

**FINISH:** unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Approval boundary

This specification records the approved product, interaction, visual, and architecture direction. Implementation begins only after the owner reviews this written spec, approves any corrections, reviews the resulting implementation plan, and selects an execution method. No push is authorized by this document.
