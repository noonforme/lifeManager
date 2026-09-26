# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

LifeOS is built for one person managing their own life. It is a private personal tool rather than a household collaboration product or a multi-user service.

## Product Purpose

LifeOS brings work shifts, personal finances, habits, and knowledge into one place. Its primary job is to make consistent tracking across these areas simple enough to maintain over time.

Success means the user can capture, review, and act on their records without the friction and inconsistency of maintaining several unrelated systems.

## Positioning

LifeOS uses a deterministic addon system to bring distinct areas of one person's life into a consistent, locally operated interface. Each addon retains its domain rules while sharing one shell, interaction model, and data-integrity standard.

## Operating Context

The user returns to LifeOS regularly to:

- record work shifts and review Lithuania-specific salary estimates;
- record income and expenses and review their balance;
- maintain habits and mark daily completion;
- capture and search personal notes;
- scan a dashboard for the state of these areas.

## Capabilities and Constraints

- FastAPI, Jinja2, HTMX, SQLite, compiled Tailwind CSS, and finite shared JavaScript form the product stack.
- The visible modules are Work Shifts, Finances, Habits, and Knowledge.
- FastAPI remains authoritative for persistence, transactions, final validation, security-sensitive decisions, SQL selection, salary calculations, and Habit calculations.
- Addons load through a deterministic, all-or-nothing staged registry and own their routes, migrations, namespaced templates, and domain behavior.
- The interface is server-rendered first and remains fully operable through ordinary HTTP behavior where required.
- All visible product language is English.
- Lithuania-specific salary rules remain explicit and are not generalized during interface work.
- Light and Dark are the only themes.
- There is one interface density and one shared native dialog.
- No client framework, client router, browser copy of persisted addon data, or optimistic persisted mutation is introduced.

## Brand Commitments

- The product name is LifeOS.
- Copy is short, direct, factual, and present-tense.
- The product should feel like a capable personal operating instrument, not a simulated terminal or IDE.
- Function communicates the brand: visual choices should clarify structure, category, state, priority, or action.

## Evidence on Hand

- The repository contains working domain, repository, route, template, and test implementations for all four addons.
- `DESIGN.md` records the currently approved interface and frontend architecture. A requested redesign may replace its visual world, but must preserve confirmed product behavior and constraints.
- No testimonials, external customer claims, benchmark claims, pricing, or marketing proof exist and none should be fabricated.

## Product Principles

1. Make recurring capture easy enough to sustain.
2. Keep each life area distinct while making the whole system feel coherent.
3. Protect data integrity and deterministic behavior before adding convenience.
4. Keep authoritative calculations and persisted decisions on the server.
5. Make current state and next actions legible at a glance.

## Accessibility & Inclusion

LifeOS targets WCAG 2.2 AA. It requires complete keyboard operation, visible focus, meaningful control boundaries, text and non-text contrast, labeled status, narrow reflow, 200% zoom support, reduced-motion support, accessible asynchronous feedback, and modal focus containment and restoration.
