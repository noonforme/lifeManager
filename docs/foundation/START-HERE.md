# Start Here

This directory is the source of truth for building LifeOS. Read it before changing behavior, design, architecture, or engineering practice.

## Authority hierarchy

When documents disagree, the earlier item wins:

1. [PRODUCT.md](PRODUCT.md) — purpose, user needs, principles, and non-goals.
2. [V1-SCOPE.md](V1-SCOPE.md) — workflows and the release boundary.
3. [DOMAIN.md](DOMAIN.md) — records, validation, calculations, and semantics.
4. [DESIGN.md](DESIGN.md) — interaction and visual system.
5. [ARCHITECTURE.md](ARCHITECTURE.md) — technical boundaries and runtime decisions.
6. [ENGINEERING.md](ENGINEERING.md) — implementation and verification practice.
7. [LESSONS.md](LESSONS.md) — provenance and non-normative context.

The approved restart specification under `docs/superpowers/specs/` records the decision that established this package. The documents above are the maintained implementation authority.

## Current milestone

The current milestone preserves the safe Django foundation and includes persisted Work and Money. Shifts can be created, reviewed, edited, deleted after confirmation, and reconciled by month with a derived salary estimate. Transactions can be created, reviewed, edited, hard-deleted after confirmation, and reconciled by month through count, inflow, outflow, and net movement. The Daily Register shows empty, ready, or unavailable Work and Money while isolating expected failures. Persisted Habits supports four habit types, structured recurrence, dated factual outcomes, archive/restore and derived streaks/momentum. Its bounded summary isolates expected failures alongside Work and Money. Local Closing Ledger assets, theme controls, readiness, and deterministic tests remain part of the foundation.

## How to work

Deliver one complete vertical slice at a time: define behavior, write a failing test, implement the smallest coherent change, verify the focused behavior, run the complete suite, and record remaining manual gaps honestly. A slice includes domain rules, server-rendered interaction, accessibility, persistence safety, and documentation where applicable.

Historical code is not an implicit specification. Do not infer requirements from an earlier implementation, import its modules, copy its application code, or access its personal data. Only this authority hierarchy may define current behavior. `LESSONS.md` records selected provenance without granting historical artifacts authority.
