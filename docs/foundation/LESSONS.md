# Lessons

This document is provenance, not specification. Current behavior is defined by the authority hierarchy in `START-HERE.md`.

## Provenance

The restart followed a read-only examination of `/home/aUser/improvedCalendar`. That location remains historical evidence only: its application code and personal data are not imported, copied, executed as part of LifeOS, or treated as implicit requirements.

## Retained lessons

- Personal-data tools need a clearly separated runtime database and disposable test database.
- Salary examples are easiest to preserve as portable decimal fixtures with explicit rounding.
- Habit momentum must be derived from completion dates so it cannot drift from its evidence.
- Empty states are legitimate domain outcomes and should be designed before populated views.
- One local date per request avoids internally inconsistent summaries around midnight.
- A domain failure should not erase unrelated registers.
- Local assets and small server-rendered pages reduce privacy and operational dependencies.

## Discarded mechanics

The restart does not retain the prior FastAPI shape, addon registry, plugin-style discovery, HTMX-specific interactions, mutable momentum score, implicit database placement, or framework-coupled domain calculations. Those mechanics solved a previous structure and do not constrain this one.

## Characterized edge cases

Historical examples exposed cases worth keeping independently of implementation: overtime may exceed worked hours without producing negative normal hours; the hourly-rate mean is unweighted across contributing shifts; normal, night, and holiday labels currently have no salary multiplier; payroll outputs need explicit half-up rounding; and duplicate same-day habit completions must count once.

These cases are encoded in `fixtures/salary-cases.json` and `fixtures/habit-momentum-cases.json`. The fixture files—not historical source—are the portable evidence future implementations must satisfy.

## Non-normative future considerations

Later planning may evaluate import/export, encrypted backup, a Knowledge domain, richer reconciliation comparisons, or data portability. Each needs an approved workflow, threat model where relevant, migration story, and deterministic acceptance tests before entering scope.
