# Version One Scope

## Release definition

Version one is complete when Work, Money, and Habits can each be reconciled through a tested local workflow and the Daily Register composes their summaries without hiding partial failure. A release includes schema migrations, deterministic domain tests, accessible server-rendered forms, recovery behavior, backup guidance, and an honest verification receipt.

## Shared states

Every register distinguishes:

- **Empty:** no qualifying records exist; this is a valid state, not an error.
- **Ready:** records exist and the current summary was derived successfully.
- **Incomplete:** records exist but need user input before a result is reliable.
- **Unavailable:** an expected operational failure prevents a summary; other registers remain usable.
- **Confirmed:** a user action committed successfully and can be reviewed.
- **Invalid:** submitted values were rejected with field-level guidance and retained input.

## Work workflow

Version one supports creating, reviewing, editing, and deleting shifts; classifying normal, night, and holiday shifts; recording worked and overtime hours plus hourly rate; deriving monthly hours, mean rate, gross pay, Lithuanian payroll deductions, total taxes, and net pay; and explaining rounding. Shift classification does not change salary in version one.

## Money workflow

Version one supports creating, reviewing, editing, and deleting income and expense transactions; recording date, amount, direction, category, and optional note; deriving monthly inflow, outflow, and net movement; and ordering entries deterministically.

## Habits workflow

Version one supports creating, reviewing, editing, and archiving habits; recording a completion once per local date; removing an erroneous completion; deriving momentum from ordered unique completion dates; and presenting gaps without punitive language.

## Daily Register workflow

The root view uses one canonical local date, shows Work, Money, and Habits in that order, links only to implemented routes, isolates expected summary failures, and never fabricates data to fill an empty panel.

## Named deferrals

The following are outside version one: bank import, payroll-provider integration, tax filing, recurring transactions, budgets, multi-currency conversion, teams, sharing, accounts, cloud synchronization, notifications, native applications, public APIs, free-form Knowledge features, automated off-device backup, and visual browser testing.
