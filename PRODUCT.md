# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

LifeOS is desktop-first in its operating model. The owner's reference to Qt describes professional desktop-tool behavior and structure, not a confirmed migration to a native toolkit. Narrow-screen access remains supported without making an enlarged tablet interface the desktop default.

## Users

LifeOS serves one trusted person managing their own life on a local device. It is a private personal tool, not a household collaboration product or a multi-user service.

## Product Purpose

LifeOS is a private, local-first personal reconciliation system. It helps the owner compare intended life with recorded life across Work, Money, and Habits, then make the smallest useful correction.

Success means the owner can capture, review, correct, and act on trustworthy records from one coherent daily entry point, understand derived values, and retain control of their local data.

The owner considers the current functionality sub-par and the current interface insufficiently tool-like. Existing implementation is evidence of available behavior, not approval of its completeness or presentation.

## Positioning

LifeOS is a dashboard and professional operating tool for personal records. It should behave like a purpose-built desktop program, not a blog, marketing website, or oversized tablet application.

Its value comes from useful workflows, truthful records, explainable calculations, and coherent domain tools—not decorative presentation or engagement mechanics.

## Operating Context

The owner returns regularly to:

- see today's date and the current state of Work, Money, and Habits;
- record work shifts and reconcile estimated pay;
- record income and expenses and review selected-month inflow, outflow, and net movement;
- maintain habits, review what is due, record factual outcomes, and inspect attention and momentum signals;
- review derived totals, correct records, and return later without their meaning drifting.

Desktop use is the primary interaction context. The dashboard is a working entry point into records and actions, not an ornamental overview.

## Capabilities and Constraints

- The current stack is a Django modular monolith with SQLite, server-rendered Django templates and forms, and local styles, scripts, and fonts.
- Core owns the shell, composition, clock, and shared presentation boundaries. Work, Money, and Habits own their records, validation, calculations, queries, and routes.
- SQLite is the single source of truth. Authoritative validation, calculations, and persisted decisions remain on the server.
- Core reading and mutation workflows work without JavaScript. Mutations use POST, CSRF protection, validation, and Post/Redirect/Get.
- Derived views do not become a second source of truth or competing persisted totals.
- Work salary estimates retain their explicit version-one formula, rounding, and deduction rates. They are not tax advice.
- Money reports selected-month movement, not an account balance, budget, forecast, tax result, or bank-import claim.
- Habits supports check, quantity, abstinence, and scheduled-chore routines with structured recurrence and factual outcomes. Missing evidence does not imply success. Archive periods preserve history.
- Habit reminders are in-app display and ordering only, not notifications. The read-only calendar projection is not a shipped calendar UI.
- Knowledge is a possible future domain, not a current shipped capability.
- Personal records stay under the owner's control. The product does not require an account, cloud synchronization, telemetry, advertising, or third-party analytics.
- Personal content must not appear in logs, readiness responses, test fixtures, screenshots, or source control. Development and verification must not discover or reuse the personal database.
- The development server is loopback-only. Deployment beyond loopback requires a separately designed security configuration.
- Runtime pages do not depend on remote CDNs.
- Version one excludes public sharing, real-time collaboration, mobile-native distribution, plugin systems, and client-side application state.

## Brand Commitments

- The product name is LifeOS.
- Copy is short, direct, factual, and explicit about record state and calculation meaning.
- The product should feel like a professional desktop tool built for sustained practical use.
- Functionality and task completion take priority over looking fancy. Cosmetic polish is not a substitute for useful capabilities.
- Do not treat the current website-like presentation as a visual direction to preserve. The owner explicitly rejects a blog-like, decorative website, or scaled-up tablet-app experience.
- Future visual-world decisions must serve this tool-first commitment. Specific palettes, typography, layouts, and components are not selected by this product record.

## Evidence on Hand

- README.md and docs/foundation/PRODUCT.md, ARCHITECTURE.md, DOMAIN.md, and V1-SCOPE.md record the current product and implementation boundaries.
- The repository contains a Django foundation and persisted Work, Money, and Habits vertical slices, with deterministic Python/Django tests and documented verification.
- docs/foundation/DESIGN.md records the incumbent Closing Ledger interface. It is implementation evidence, not owner approval of the current visual direction; the desktop-tool commitment above supersedes conflicting aesthetic intent.
- app.sh provides local startup, tests, and project checks.
- No testimonials, external customer claims, benchmark claims, pricing, or marketing proof are established and none should be fabricated.

## Product Principles

1. Truth before motivation: represent empty, unavailable, incomplete, and confirmed states honestly.
2. Useful tools before decoration: make recurring capture, comparison, correction, and action practical on desktop.
3. Records before dashboards: derived views explain owned records rather than compete with them.
4. Local and private by default: protect the owner's data and keep authoritative behavior explicit.
5. Calm, complete workflows: avoid gamified pressure, artificial urgency, and hidden state; deliver trustworthy slices end to end.

## Accessibility & Inclusion

Preserve complete keyboard operation, semantic structure, visible focus, labeled controls and states, sufficient text and non-text contrast in light and dark themes, accessible feedback, reduced-motion support, text spacing, zoom, and narrow reflow. Desktop-first must not mean mouse-only or inaccessible at smaller widths.

## Open Product Decisions

The owner has identified inadequate functionality but has not yet specified which workflows or capabilities are missing. Future feature work must establish those gaps rather than infer a feature roadmap from dissatisfaction with the current interface.
