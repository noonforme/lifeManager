# Design

## Closing Ledger thesis

LifeOS should feel like a private ledger prepared for daily use: dense enough to compare facts, calm enough to revisit, and explicit about every boundary. The visual language uses paper-like grounds, ink, hard rules, flat panels, tabular values, and restrained domain accents. It avoids generic dashboard gloss.

## Tokens

The maintained token vocabulary is `ground`, `surface`, `ink`, `muted`, `boundary`, `action`, `action-ink`, `confirmed`, `confirmed-ink`, `work`, `money`, `habits`, and `focus`, with rail colours supporting the shell. Every semantic foreground/background pair must meet its applicable WCAG contrast threshold in both light and dark palettes.

## Typography

Barlow carries interface language. JetBrains Mono carries dates, amounts, rates, durations, calculated values, and other content whose alignment communicates meaning. Fonts are bundled locally. System fallbacks preserve function when a font cannot load.

## Shell

A persistent rail holds the LifeOS mark and native navigation disclosure. The workspace provides a compact context strip, theme choice, permanent polite-status and assertive-alert regions, and exactly one main region. The Daily Register begins with one page heading and one canonical local date.

## Register components

Work, Money, and Habits appear in deterministic order. Each register has a stable heading, domain accent, visible state label, concise summary, and—only when implemented—a clear primary link or action. Empty and unavailable panels remain full members of the layout rather than disappearing. Money presents count, inflow, outflow, and net movement before a transaction table containing only Date, Direction, Category, and Amount; notes remain on canonical review pages rather than monthly rows.

## Forms

Forms use visible labels, explanatory hints before errors, appropriate native controls, and a single clear submission action. Validation preserves safe input, associates field errors programmatically, and adds a concise error summary when multiple corrections are needed. Destructive actions require an explicit review step and name the affected record.

## Feedback and errors

Success messages describe what was saved. Errors describe what the user can do next without exposing internals. Expected domain failure affects its own register, not the entire Daily Register. Colour never carries state alone.

## Themes

System is the default. Light and dark are explicit alternatives. Theme preference is a local convenience, not authoritative application data. The page must remain readable when scripts or storage are unavailable.

## Responsive behavior

At narrow widths the rail becomes a normal header, controls wrap, page metadata stacks, and registers become a single column. Content must not cause page-level horizontal scrolling; wide tables or code receive their own labelled scroll region.

## Accessibility

Use semantic HTML before ARIA, preserve logical heading order, provide a skip link, maintain visible two-pixel focus, target at least 44 by 44 CSS pixels for controls, support text spacing and zoom, honour reduced motion, and keep source and visual order aligned. Status and alert regions exist before messages arrive.

## Prohibited patterns

Do not use rounded floating cards, glass effects, gradient decoration, icon-only actions, hidden labels, hover-only disclosure, fake links, disabled-looking empty states, auto-advancing content, decorative charts without equivalent data, or scripts that replace native navigation or authoritative records.
