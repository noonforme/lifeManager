# Architecture

## Shape

LifeOS is a Django modular monolith. `lifeos.core` owns composition, clock access, shared presentation boundaries, readiness, and the shell. `lifeos.work`, `lifeos.money`, and `lifeos.habits` own their records, validation, calculations, queries, and routes. Domain modules may use shared core primitives but must not reach into another domain's persistence internals.

The interface is server-rendered Django templates and forms over ordinary HTTP. Mutations use POST, CSRF protection, validation, and Post/Redirect/Get. JavaScript may enhance preferences or ergonomics but is never required to read records, navigate, validate authoritative rules, or commit changes.

## Persistence

SQLite is the single source of truth. The default personal database is `${XDG_DATA_HOME:-~/.local/share}/lifeos/lifeos.sqlite3`; `LIFEOS_DATABASE_PATH` may explicitly select another absolute path outside the source repository. Runtime creates only the required parent directory. Source control, tests, checks, and documentation tooling must not discover or reuse the personal database. Test settings import only side-effect-free common settings, so they never resolve or create a runtime personal-data location.

Each schema change ships as a Django migration. Multi-record state changes use `transaction.atomic`. Derived summaries are calculated from owned records rather than persisted as competing totals unless a later authority document explicitly defines a cache and its invalidation.

## Work slice

`lifeos.work.models` owns Shift persistence and invariant validation. `calculations` owns pure immutable Decimal salary policy, `queries` owns month and nearest-record semantics, `forms` owns input presentation, `views` owns transactions and HTTP workflows, and `summary` adapts Work results to core's immutable presentation boundary. Core does not import Work models or recalculate salary.

The Work routes are server-rendered and namespaced beneath `/work/`. Derived salary values are calculated from selected Shift records and are never persisted as competing totals.

## Money slice

`lifeos.money.models` owns Transaction persistence and invariant validation. `calculations` owns pure immutable Decimal monthly-movement policy, `queries` owns Money's month selection and one-snapshot query semantics, `forms` owns strict lexical input parsing, `views` owns atomic HTTP workflows, and `summary` adapts Money results to core's immutable presentation boundary. Money never imports Work, and Core neither imports Transaction nor reproduces Money calculations.

Money routes are server-rendered and namespaced beneath `/money/`. Register and detail are GET-only; create, edit, and confirmed hard delete use POST with CSRF and Post/Redirect/Get. Monthly values are derived from one materialized Transaction snapshot and never persisted as competing totals.

## Habits slice

`lifeos.habits` owns relational Habit/configuration/exception/pause/archive-period/occurrence persistence. Pure recurrence and calculation modules consume immutable explicit-date inputs. Query snapshots materialize owned configuration and evidence before rendering. Forms and views own coherent atomic mutations, strict lexical input and private DatabaseError recovery. Core consumes only the existing immutable summary boundary; Habits imports neither Work nor Money.

The namespaced `/habits/` workflow uses ordinary HTTP, CSRF and Post/Redirect/Get. The Daily Register labels Due today, Completed, Needs attention and Active habits in that order. Attention is bounded to the previous 90 days. Reminder time is only in-app display/ordering. `calendar.project_events` is a read-only immutable projection limited to 366 inclusive dates, not a calendar UI or a second source of truth.

## Dates, time, and composition

Stored timestamps are timezone-aware. User-facing calendar behavior uses the configured local timezone. The Daily Register obtains one date from the injected clock and passes that exact date to each domain summary in Work, Money, Habits order. This prevents midnight drift inside one response.

Summaries cross the domain boundary as immutable presentation values. Expected operational failures become a domain-labelled unavailable summary and are logged without personal content. Unexpected programming errors propagate so tests and operators can see them.

## Security

The development server binds to loopback, accepted hosts are restricted to loopback names, and Django's CSRF, clickjacking, session, security, and escaping protections remain enabled. Secrets and personal record content do not enter committed settings. A deployment beyond loopback requires a separate security configuration for TLS, secure cookies, hostnames, and secret management.

## Readiness

`/ready/` performs the smallest database liveness query and returns plain text: `ready` with 200 or `unavailable` with 503. It exposes no paths, SQL, record counts, exception text, or personal values.

## Assets

Styles, scripts, and fonts are local. Downloaded font artifacts are pinned by SHA-256 and covered by deterministic tests. Runtime pages do not depend on remote CDNs.

## Future paths

Knowledge, if later approved, becomes another domain rather than miscellaneous fields in core. Backup begins with documented, quiescent copying of the SQLite database to an owner-selected destination; scheduled or encrypted backup requires a dedicated design covering consistency, retention, restore testing, and secret handling.

## Rejected complexity

Version one rejects microservices, background queues, event buses, client-side application state, GraphQL, REST duplication of server-rendered flows, plugin systems, generic addon registries, repository abstractions without a second backend, and distributed caches. Add complexity only when a concrete approved workflow cannot be delivered safely without it.
