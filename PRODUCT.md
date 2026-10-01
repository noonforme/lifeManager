# Product

<!-- impeccable:product-schema 1 -->

## Platform

desktop

LifeOS is a native Linux desktop application built with Flutter. Narrow windows remain usable without making an enlarged tablet interface the desktop default.

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

- The stack is a native Flutter desktop application with a local SQLite database through Drift, Riverpod state, and GoRouter structural routes.
- Work is the shipped domain: employment, versioned pay agreements, live and manual shifts, pay periods, payslip evidence, reconciliation, and void-and-replace correction. Today, Money, and Habits are honest unavailable destinations until their native domains are designed.
- SQLite is the single source of truth. Derived views do not become a second source of truth or competing persisted totals.
- Mutations report explicit outcomes (committed, invalid, stale, missing, unavailable, uncertain); nothing is retried or overwritten silently.
- Personal records stay under the owner's control. The product does not require an account, cloud synchronization, telemetry, advertising, remote assets, or third-party analytics.
- Personal content must not appear in logs, test fixtures, screenshots, or source control. Development and verification use guarded disposable roots and synthetic data only.
- Earlier prototypes are not migrated; their data is never read or imported.
- Version one excludes public sharing, collaboration, mobile distribution, and plugin systems.

## Brand Commitments

- The product name is LifeOS.
- Copy is short, direct, factual, and explicit about record state and calculation meaning.
- The product should feel like a professional desktop tool built for sustained practical use.
- Functionality and task completion take priority over looking fancy. Cosmetic polish is not a substitute for useful capabilities.
- Do not treat the current website-like presentation as a visual direction to preserve. The owner explicitly rejects a blog-like, decorative website, or scaled-up tablet-app experience.
- Future visual-world decisions must serve this tool-first commitment. Specific palettes, typography, layouts, and components are not selected by this product record.

## Evidence on Hand

- README.md and docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md record the current product and implementation boundaries.
- The repository contains the native Flutter foundation and the Work domain with deterministic unit, widget, and end-to-end synthetic tests.
- app.sh provides local startup, tests, and project checks.
- No testimonials, external customer claims, benchmark claims, pricing, or marketing proof are established and none should be fabricated.
