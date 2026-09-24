# Architecture

## Shape

LifeOS is a Django modular monolith. `lifeos.core` owns composition, clock access, shared presentation boundaries, readiness, and the shell. `lifeos.work`, `lifeos.money`, and `lifeos.habits` own their records, validation, calculations, queries, and routes. Domain modules may use shared core primitives but must not reach into another domain's persistence internals.

The interface is server-rendered Django templates and forms over ordinary HTTP. Mutations use POST, CSRF protection, validation, and Post/Redirect/Get. JavaScript may enhance preferences or ergonomics but is never required to read records, navigate, validate authoritative rules, or commit changes.

## Persistence

SQLite is the single source of truth. The default personal database is `${XDG_DATA_HOME:-~/.local/share}/lifeos/lifeos.sqlite3`; `LIFEOS_DATABASE_PATH` may explicitly select another absolute path outside the source repository. Runtime creates only the required parent directory. Source control, tests, checks, and documentation tooling must not discover or reuse the personal database. Test settings import only side-effect-free common settings, so they never resolve or create a runtime personal-data location.

Each schema change ships as a Django migration. Multi-record state changes use `transaction.atomic`. Derived summaries are calculated from owned records rather than persisted as competing totals unless a later authority document explicitly defines a cache and its invalidation.

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
