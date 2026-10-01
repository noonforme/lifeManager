---
name: LifeOS
description: Private local-first operations desk for personal reconciliation records.
colors:
  ground: "#eef0f3"
  surface: "#fff"
  ink: "#202731"
  muted: "#526071"
  boundary: "#8290a1"
  action: "#23569b"
  action-ink: "#fff"
  confirmed: "#e3edf8"
  confirmed-ink: "#163c70"
  work: "#23569b"
  money: "#6b551d"
  habits: "#3b662f"
  focus: "#164d91"
  rail: "#e3e7ed"
  rail-ink: "#202731"
  error: "#a32532"
  hover: "#e9eef5"
typography:
  display:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.3
  headline:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "1.2rem"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.5
  mono:
    fontFamily: "ui-monospace, SFMono-Regular, Consolas, monospace"
    fontFeature: "tabular-nums"
rounded:
  control: "2px"
spacing:
  2: "0.5rem"
  3: "0.75rem"
  4: "1rem"
  5: "1.25rem"
components:
  button-primary:
    backgroundColor: "{colors.action}"
    textColor: "{colors.action-ink}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "0.55rem 0.9rem"
    height: "44px"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "0.55rem 0.9rem"
    height: "44px"
  field:
    backgroundColor: "{colors.ground}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "0.55rem"
    height: "44px"
---

# Design System: LifeOS

> **Superseded direction (2026-10-01).** The owner approved a replacement world: Office Machine, with a book tree, desks, journal, formula bar and record history. The target system is specified in `docs/superpowers/specs/2026-10-01-lifeos-office-machine-shell-design.md` (section 4 holds the tokens). This file still describes the shipped implementation and will be rewritten from the built shell when plan `2026-10-01-lifeos-office-machine-shell.md` finishes.

## Overview

**Creative North Star: "The Neutral Operations Desk"**

LifeOS is implemented as a desktop-first operations desk: cool-gray surfaces, flat bounded panes, compact system typography, and tabular values place truthful monthly records and their correction ahead of decorative staging. The Work workspace keeps the monthly table visible while an adjacent inspector handles the selected record; at narrower widths the panes stack without removing either workflow.

The native Flutter workbench implements the light theme with a high-contrast variant. This record makes no claim of visual approval until the release visual review is complete.

**Key Characteristics:**
- Light cool-neutral shell with graphite dark-mode counterpart.
- Flat white panes, 1px boundaries, and restrained blue actions and selection.
- Compact system UI type with monospaced tabular record values.
- Persistent 10.5rem rail and a work-table/inspector workspace.

## Colors

Cool neutrals organize the workspace; blue is the principal action, Work, focus, and selection signal, while Money, Habits, and error retain narrow semantic roles.

### Primary
- **Operations Blue:** action links and buttons, Work identity, and interactive focus.
- **Confirmed Blue:** selected table row and selected theme-control background, paired with confirmed ink.

### Secondary
- **Money Olive-Brown:** Money’s domain role.
- **Habits Green:** Habits’ domain role.
- **Error Red:** invalid controls, error text, and destructive links.

### Neutral
- **Cool Ground:** application background and field fill.
- **White Surface:** panes, panels, context strip, and secondary actions.
- **Graphite Ink:** primary text and rail text.
- **Muted Slate:** supporting labels and qualifications.
- **Boundary Slate:** shell, pane, row, and control divisions.
- **Rail Gray:** desktop navigation rail.
- **Hover Wash:** table-row and secondary-action hover fill.

### Named Rules
**The Blue-For-Operation Rule.** Use the action role for navigation, primary actions, Work identity, focus, and selected-state emphasis; do not spread it as decoration.

**The Semantic-State Rule.** Error red and confirmed blue supplement explicit text, underlines, and selected-state semantics; color does not stand alone.

## Typography

**Display Font:** system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif.
**Body Font:** system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif.
**Label/Mono Font:** ui-monospace, SFMono-Regular, Consolas, monospace.

**Character:** The system UI stack maintains compact desktop-tool language. Monospace and tabular figures make dates, rates, hours, and financial values inspectable in tables and summaries.

### Hierarchy
- **Display** (700, 1.5rem, 1.3): page headings.
- **Headline** (600, 1.2rem, 1.3): register titles.
- **Section Heading** (default weight, 1.15rem, 1.3): panel summaries and workspace headings.
- **Body** (400, 15px, 1.5): controls, records, and explanatory content.
- **Data** (400, tabular numerals): `.mono` values, with `time` also using tabular figures.

### Named Rules
**The Fixed-Scale Rule.** Preserve the compact implemented type scale; page headings are 1.5rem rather than oversized display treatment.

## Layout

The desktop shell is a two-column grid with a 10.5rem rail and flexible workspace. The context strip uses `0.5rem 1.25rem` padding and main uses `1.25rem`; panels repeatedly use 1rem or 1.25rem padding and 1rem gaps.

The Work workspace is a grid of `minmax(0, 1.8fr)` table pane and `minmax(20rem, 1fr)` inspector. At 1100px and below it becomes one column; the inspector exposes a scroll margin for return navigation. Registers are vertically stacked bounded sections. Wide tables scroll only within their own horizontal-scroll region.

At 700px and below, the rail becomes a top header, navigation links wrap, main padding becomes 1rem, and metric grids use two columns. At 400px, metric grids become one column.

## Elevation & Depth

The system has no shadows. White surfaces on cool ground, 1px boundary lines, table header grounds, and controlled hover/selection washes establish hierarchy. Motion is immediate; reduced-motion mode shortens animation and transition duration and disables smooth scrolling.

### Named Rules
**The Flat-Pane Rule.** Distinguish workspace regions with bounds and tonal changes, never with floating elevation, blur, glass, or gradient effects.

## Shapes

The form language is almost square. Inputs and button-like controls use a 2px radius; panes, summary panels, tables, and the rail use straight 1px boundaries. All interactive controls target at least 44px in height or width as implemented.

## Components

### Buttons
- **Shape:** minimally softened (2px radius) and at least 44px tall.
- **Primary:** Operations Blue fill and action ink, 1px action border, 600 weight, `0.55rem 0.9rem` padding; hover darkens via brightness filter.
- **Secondary:** white-surface `.button-link` with boundary border and ink; hover changes to the hover wash.
- **Focus:** shared visible 2px focus outline offset by 3px.

### Cards / Containers
- **Corner Style:** square bounded panes.
- **Background:** white surface on cool ground.
- **Shadow Strategy:** none.
- **Border:** 1px boundary; selected table records receive confirmed fill instead of extra elevation.
- **Internal Padding:** 1rem or 1.25rem according to the panel.

### Inputs / Fields
- **Style:** cool-ground fill, 1px boundary, 2px radius, ink text, and `0.55rem` padding.
- **Focus:** shared visible focus outline.
- **Error:** a 2px error border with error-colored field label/text.

### Navigation
- **Style:** a 10.5rem rail with rail-gray background, 1px end boundary, 700-weight LifeOS mark, and native `details` disclosure.
- **State:** links are text-labelled; the current page has white surface, boundary border, 700 weight, and underline. Hover uses white surface.
- **Mobile treatment:** rail becomes an inline-start header at 700px and links wrap.

### Work Workspace
- **Character:** a table-first monthly review pane beside a record inspector.
- **Table:** compact `.65rem .8rem` cells, cool-ground header, hover wash, right-aligned numeric Work columns, and confirmed selection state.
- **Responsive behavior:** stack table and inspector at 1100px; selection navigation keeps the monthly snapshot available while the inspector opens nearby or below.

## Do's and Don'ts

### Do:
- **Do** preserve the 10.5rem desktop rail, the 1100px Work-pane stack, and the 700px shell reflow.
- **Do** use flat surface panes with 1px boundary lines and restrained hover/confirmed washes.
- **Do** keep controls at least 44px and retain the 2px, 3px-offset focus outline.
- **Do** use system UI for interface language and monospaced tabular figures for inspectable values.

### Don't:
- **Don't** add large editorial headings, paper-ledger styling, display fonts, or ornamental animation; the implemented world is a compact system-UI operations desk.
- **Don't** add shadows, gradients, glass effects, or rounded floating cards.
- **Don't** replace text-labelled native navigation and selection links with glyph-only or script-dependent controls.
- **Don't** claim visual approval or finished screenshot review; no desktop or mobile screenshots were inspected.
