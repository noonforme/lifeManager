# Domain

## Shared semantics

A record has a stable identifier and explicit owner-domain meaning. Calendar dates are strict ISO `YYYY-MM-DD` values interpreted in the configured local timezone. Timestamps are timezone-aware and reserved for audit ordering. User-entered text is trimmed according to field rules, stored as text rather than trusted markup, and escaped on output.

Money and rates use exact decimal arithmetic; binary floating point is prohibited. Stored monetary values use the currency's two-place precision. Intermediate salary calculations remain exact and only named outputs round using `ROUND_HALF_UP` to two decimal places. Validation errors identify the field and rule without echoing secrets or internals.

Lists use deterministic ordering: primary business date descending for histories, then creation timestamp descending, then stable identifier. Daily composition order is Work, Money, Habits. Empty results are valid. Expected operational failure is represented as unavailable; invalid input is not an operational failure.

## Work

### Shift record

A shift contains:

- local work date;
- shift type: `normal`, `night`, or `holiday`;
- worked hours, a non-negative decimal;
- overtime hours, a non-negative decimal;
- hourly rate, a non-negative decimal money value;
- optional plain-text note;
- creation and update timestamps.

Overtime may exceed worked hours. Normal hours are `max(worked hours - overtime hours, 0)`. Overtime is paid at `1.5 × hourly rate`. In version one, shift type is descriptive and has no salary multiplier.

For a selected month, the mean hourly rate is the unweighted arithmetic mean of rates for included shifts. Gross pay is the sum of `normal hours × rate + overtime hours × rate × 1.5` for each shift. Version-one deductions use the characterized rates: GPM is `gross × 0.20`, VSD is `gross × 0.1252`, and PSD is `gross × 0.0698`. Each named output rounds half-up to two decimal places. Total taxes are the sum of displayed GPM, VSD, and PSD, and net is displayed gross minus displayed total taxes. Implementation must satisfy `fixtures/salary-cases.json` and expose the formula and rounding to the user.

A shift is invalid when its date, type, decimal syntax, scale, or bounds are invalid. Domain policy must define practical upper bounds before accepting records; forms and models enforce the same constraints.

## Money

### Transaction record

A transaction contains:

- local transaction date;
- direction: `income` or `expense`;
- positive decimal amount;
- category as required plain text or an owned category reference;
- optional plain-text note;
- creation and update timestamps.

Amount is always positive; direction supplies the sign. Monthly inflow is the sum of income amounts, outflow is the sum of expense amounts, and net movement is inflow minus outflow. Outputs round half-up to two decimal places. Editing or deleting a transaction immediately changes derived totals; totals are not independent records.

## Habits

### Habit record

A habit contains a stable identifier, non-empty name, active/archived state, creation timestamp, and optional archive timestamp. Names are displayed as plain text. Archiving preserves completions and removes the habit from active-entry choices without rewriting history.

### Completion record

A completion associates one habit with one local completion date. The pair `(habit, completion date)` is unique. Repeated submission for the same day must not create another completion. Removing a mistaken completion removes that date from derivation.

Momentum is derived, never independently mutated. Deduplicate and sort completion dates ascending. Start at zero. For each date apply:

`next = round(previous × exp(-0.1 × elapsed_days) + 1, 2)`

Elapsed days is the difference from the previous unique completion. The first completion uses one elapsed day, which is immaterial because previous is zero. Rounding occurs at every completion. `fixtures/habit-momentum-cases.json` defines portable examples, including duplicates, gaps, leap day, and year rollover.

## Error and transaction semantics

Validation failure commits nothing and returns the submitted form with safe values intact. A successful single-record mutation commits once and redirects to a canonical review page. A mutation that changes multiple owned records is atomic. Missing records return not found rather than silently creating replacements. Conflicts such as a duplicate completion produce an idempotent outcome or a clear validation message as defined by the workflow; they never create duplicate evidence.

Unexpected exceptions are not converted into plausible domain data. Logs identify operation and domain while excluding notes, amounts, personal paths, and exception text that may contain personal content.

## Fixture schemas

Both fixture files have `schema_version: 1` and a non-empty `cases` array with unique string IDs.

`fixtures/salary-cases.json` supplies one or more shifts per case. All numeric inputs and expected outputs are decimal strings with two places. The file declares exact intermediate arithmetic and output rounding.

`fixtures/habit-momentum-cases.json` supplies input `completion_dates`, sorted/deduplicated `expected_unique_dates`, and a two-place string `expected_momentum`. Dates are strict ISO calendar dates. A schema change requires a new version and an explicit compatibility decision; existing case meaning must not change silently.
