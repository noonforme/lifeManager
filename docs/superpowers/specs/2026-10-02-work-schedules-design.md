# Work Schedules Design

Date: 2026-10-02
Status: approved in conversation, awaiting written-spec review
Depends on: `2026-10-02-lifeos-millennium-shell-design.md` (built first; every
screen here uses its components)
Changes: the Work domain of `2026-09-29-lifeos-native-foundation-work-design.md`
and `2026-10-01-work-employments-premiums-design.md` where stated.

## 1. Purpose

The owner works a fixed rotation (for example 3 days, 3 off, 3 nights, 3 off,
12 hours with a 30-minute break) and does not want to track shifts live.
LifeOS lets them describe a rotation once, see every planned shift and its
expected pay ahead of time, adjust single days, and confirm worked days in
bulk. Confirmed days are the records payslips reconcile against. The live
start/stop tracker is removed.

## 2. Decisions

| Topic | Decision |
|---|---|
| Plan vs record | Planned shifts are derived from schedules and never stored. Confirming a day creates the record. |
| Editor | "Blocks": the cycle is a list of count × shift type (or Off). |
| Breaks | Each shift type has fixed breaks (start time and length). |
| Exceptions | Per date: change times or type, cancel with a reason, leave (paid), extra shift. |
| Leave pay | Percent of average hourly earnings over the 3 full calendar months before the leave's month. Vacation 100 %, sick 62.06 % for the first 2 calendar days of an illness, 0 % after. Labelled defaults, not legal advice. |
| Overtime | For scheduled shifts, only paid time outside the planned start–end. Extra shifts: all overtime when flagged. Unscheduled manual shifts keep the agreement threshold. |
| Live tracker | Removed: running and on-break states and every control and display that drives or shows them. |
| Style | Millennium only; every choice mimics the 2001 desktop era. |

## 3. Domain

### 3.1 Schedule

```
WorkSchedule
  id, employmentId, name, timezoneId
  version            1, 2, ... per schedule
  cycleStart         LocalDate: the date that is cycle day 1
  inUseFrom          LocalDate
  inUseUntil         LocalDate? (open when null)
  shiftTypes         List<ShiftType>
  blocks             List<CycleBlock>   (at least one, total length 1..366)
  createdAtUtc, revision
```

- Versioning follows agreements: a new version starts the day after the
  previous version's `inUseUntil`. Versions of one schedule never overlap.
- At most one schedule version is in use per employment on any date.
  Overlap is an `Invalid` outcome with field `inUseFrom`.
- A version used by a confirmed day cannot be edited in place; saving asks
  for a date and creates the next version from it (section 6.4).
- Deleting a schedule is allowed only while no confirmed day uses it.

### 3.2 Shift type

```
ShiftType
  id, name (unique within the version, 1..24 chars)
  start              LocalTime
  end                LocalTime
  endDayOffset       0 or 1 (1 when the shift crosses midnight)
  breaks             List<FixedBreak>
FixedBreak
  start              LocalTime
  dayOffset          0 or 1 (relative to the shift's start date)
  minutes            1..240
```

Breaks lie inside the shift and do not overlap; the shift is at most 24 h.
Shift types are copied into each version, so changing a type creates a new
version like any other change.

### 3.3 Cycle

```
CycleBlock
  count              1..99
  shiftTypeId        ShiftTypeId? (null = Off)
```

Cycle day for a date `d`: `((d − cycleStart) mod length) + 1`, using whole
local days and a non-negative modulo, so dates before `cycleStart` follow
the same rotation backwards.

### 3.4 Planned shift (derived)

For an employment and a date range, the planner:

1. Finds the version in use on each date.
2. Maps the cycle day to a block; Off yields nothing.
3. Builds start and end instants on the schedule's timezone wall clock using
   the existing fold rules (a daylight-saving gap moves to the first valid
   instant; an overlap uses the first occurrence) and places the breaks.
4. Applies the day exception for that date, if any (3.5).
5. Drops dates that already have a confirmed day (3.6).

A planned shift carries: date, schedule id and version, shift type (or
"extra"), planned start and end, breaks, and whether it is changed.

### 3.5 Day exception (stored)

One per employment and date.

| Kind | Fields | Effect on the plan |
|---|---|---|
| Changed | start, end, breaks, shiftTypeId? | Replaces that day's times. The overtime window is the chosen type's start–end when the type changed, otherwise the original type's. |
| Cancelled | reason: swapped, dayOff, other; note? | No shift that day; unpaid. Illness is recorded as Leave › Sick, never as a cancellation. |
| Leave | leaveType: vacation, sick; illnessStartedOn (sick only) | No shift; a leave day for the original planned paid hours. |
| Extra | start, end, breaks, shiftTypeId?, countsAsOvertime | A shift on a date where the cycle has Off. |

- Changed, Cancelled and Leave need a planned shift on that date; Extra needs
  an Off day. Otherwise the outcome is `Invalid`.
- An exception can be edited or removed until its date is confirmed.
- When a new schedule version changes what a date holds, an exception that no
  longer fits (for example Changed on a date that is now Off) is kept but
  shown as **Needs review** on that date; it is ignored by the planner until
  edited or removed.

### 3.6 Confirmed day

- **Worked:** the existing finalized `WorkShift`, plus nullable link columns
  `scheduleId`, `scheduleVersion`, `plannedDate`, `plannedStartUtc`,
  `plannedEndUtc`, and `isExtra`, `extraCountsAsOvertime`. Unscheduled
  manual shifts leave them null. Void-and-replace correction works as today
  and keeps the links.
- **Leave:** a new `LeaveRecord`: id, employmentId, date, leaveType,
  illnessStartedOn?, paidMinutes, agreementId, scheduleId, scheduleVersion,
  state (confirmed, voided), void reason and replacement like shifts,
  createdAtUtc, revision. Leave records have History like every record.
- Confirming is idempotent per date: a date with a confirmed day is never
  confirmed again; the outcome for a repeat is `Stale`.

### 3.7 Agreement additions

- `vacationPercent` (default 100), `sickEmployerPercent` (default 62.06),
  `sickEmployerDays` (default 2), stored as exact fractions like multipliers.
- Agreement form shows them in a **Leave pay** group box with the existing
  "defaults, not legal advice" note.

### 3.8 Removing the live tracker

- `ShiftState.running` and `ShiftState.onBreak` are removed. A migration
  turns any running or on-break shift into a draft with its recorded start
  and any finished breaks; an unfinished break is dropped. The owner
  finishes it by hand (the existing draft revision flow).
- Removed: start, break and end commands and services
  (`shift_lifecycle_service.dart`), `RunningShiftInspector`,
  `OnBreakShiftInspector`, the lifecycle pane, Start shift in quick add, the
  running-shift status panel, the active-shift query, and their tests.

## 4. Pay

All pay uses the existing premium engine (segments, night window, holiday
calendar, stacking) and is explained in the **Working** group box.

### 4.1 Planned shift

Planned paid time (shift minus breaks) priced with night and holiday
premiums, no overtime. Shown as **Planned**; never stored or reconciled.

### 4.2 Confirmed scheduled shift

The segment splitter gains overtime **windows** in place of a threshold:
paid time before `plannedStartUtc` or after `plannedEndUtc` is overtime. For
a Changed day the window is the chosen shift type's start–end when the
type changed, otherwise the original type's.
Extra shifts: every second is overtime when `extraCountsAsOvertime`, none
otherwise. Shifts without schedule links keep the agreement's threshold.

### 4.3 Leave

- **Hours:** the planned paid minutes of the shift the leave replaces.
- **Average hourly earnings:** the expected pay of confirmed shifts and
  confirmed paid leave of the same employment whose dates fall in the 3 full
  calendar months before the leave's month, divided by their paid hours.
  Computed in exact minor units with the rounding rule shifts use.
- **Fallback:** with no confirmed paid time in that window, the agreement's
  hourly rate is used and Working says "No confirmed work in the 3 months
  before; using the agreement rate".
- **Vacation:** hours × average × `vacationPercent`.
- **Sick:** a day whose date is within `sickEmployerDays` calendar days from
  `illnessStartedOn` (that day counting as day 1) pays hours × average ×
  `sickEmployerPercent`; later days pay 0.00 with the note "Paid by the
  social insurer, not on your payslip". `illnessStartedOn` defaults to the
  earliest date of a run of sick leave days ending at this date in which
  only Off days separate them, and can be edited (for example to an Off day
  the illness started on).
- Leave uses the agreement in effect on its date.

### 4.4 Reconciliation

A pay period's expected total is its confirmed shifts plus its confirmed
leave pay, per basis and currency as today. Unconfirmed planned days are
excluded; the period shows "N planned days not yet confirmed" when any of
its dates are past and unconfirmed.

## 5. Shell Integration

- **Books tree** under each employment: Calendar, Shifts, Leave, Schedules,
  Pay periods, Payslips, Agreements. Calendar is the default sheet when a
  schedule is in use today; otherwise Shifts.
- **View dropdown** lists the same sheets.
- **Status bar** first panel: "N days to confirm" (past planned days not
  confirmed) or nothing. It replaces the running-shift panel.
- **Books count badge** on the employment: days to confirm.
- **Quick add (Add ▾):** Manual shift, Extra shift…, Leave…, Pay period,
  Payslip, Employment, Agreement, Schedule. Start shift is removed.
- **Work tasks** (task pane): Confirm worked days…, New schedule…, Add a
  shift, New pay period, Record payslip, Save this view….
- **Desks:**
  - New sheet `work.nextShifts`: the next 5 planned shifts (date, type,
    times, planned pay).
  - `work.needsYou` gains "N days to confirm" with an **Open** link to the
    confirm dialog.
  - The Today starter desk becomes Journal recent, Needs you, Next shifts.
    Existing desks are not changed; Reset desk applies the new starter.
  - `work.monthChecklist`: "No drafts or running shifts" becomes "Every past
    planned day is confirmed".

## 6. Screens

All screens follow the Millennium shell spec (property sheet, group boxes,
push buttons, era dropdowns, information panels). Calendar and cycle text is
never smaller than 11 px.

### 6.1 Calendar view

- Header row: ‹ and › push buttons, **Month** and **Year** dropdowns, and
  **Today**.
- A 7-column month grid (weeks start Monday) in the list style: bevelled
  weekday headers, white cells, out-of-month days on the face colour.
- Each cell shows the date and at most two entries; more show "+1 more".
  Entries are written words with a small colour swatch:
  - planned: outlined, e.g. "Day 07:00–19:00"
  - confirmed: filled, same words
  - changed: words plus "changed"
  - Cancelled: "Cancelled · Swapped" (type name struck through, reason written)
  - Leave: "Vacation" or "Sick"
  - Extra: "Extra 08:00–20:00"
  - Needs review: "⚠ Needs review"
- Today has the amber outline; the selected day has the dotted focus
  rectangle and selection fill.
- Arrow keys move the selection; Enter opens the day; Page Up/Down change
  month.
- Below the grid, a status line: shifts, paid hours, planned pay and
  confirmed pay for the month.

### 6.2 Day in the property sheet

- Title: the date and weekday.
- **Working** group box for the selected pay figure.
- **Planned shift:** facts (type, start, end, breaks, paid time, planned
  pay) and push buttons **Confirm** (default), **Change…**, **Cancel
  shift…**, **Mark as leave…**.
- **Off day:** "No shift planned" and **Add extra shift…**.
- **Confirmed:** the existing shift or leave detail with **Correct…**.
- **Change…** opens a form in the sheet: start, end, breaks, shift type
  dropdown; Save (default) / Cancel. **Cancel shift…** and **Mark as
  leave…** open small dialogs with radio buttons for the reason or leave
  type, and the illness start date for Sick.

### 6.3 Confirm worked days dialog

- Era dialog "Confirm worked days" with a list: a checkbox, date, what
  (Day / Night / Extra / Vacation / Sick), times, paid time, pay. Every past
  unconfirmed day up to yesterday is listed and ticked.
- Footer: "12 days · 138:00 paid · EUR 2,714.40", then **Confirm**
  (default) and **Cancel**.
- Confirm runs one transaction per day and reports each failure in the list
  (with its outcome wording); committed days leave the list.

### 6.4 Schedules view and Schedule properties

- Schedules view: a list of schedules and versions (name, employment, in
  use from, until, cycle length, state In use / Ended / Future).
- **Schedule properties** (a property sheet page, or a dialog when opened
  from quick add):
  - **Schedule** group box: Name, Employment dropdown, Timezone, Cycle
    starts on, In use from, In use until (blank = open).
  - **Cycle — N days** group box: a list of blocks, each with ⋮⋮ (drag, or
    Alt+↑/↓), a count field, "×", and a shift-type dropdown (including
    Off); the type's times and break summary on the right. **Add block**
    and **Shift types…** push buttons.
  - **Preview — Month YYYY** group box: the calendar grid in read-only form
    with ‹ › and the month's shift count, paid hours and expected pay.
  - Footer: **Save schedule** (default) and **Cancel**. When the version is
    used by a confirmed day, Save asks "Use the new cycle from:" with a date
    field (default tomorrow) and creates the next version.
- **Shift types dialog:** a list (Name, Start, End, Breaks, Paid) with
  **Add…**, **Edit…**, **Remove** (Remove is disabled for a type used by the
  cycle). Edit type dialog: Name, Start, End with "+1 day" checkbox, and a
  Breaks list (start, length) with Add / Remove.

### 6.5 Leave view

A list of leave records (date, type, hours, average used, percent, pay,
state) with property sheet detail and History.

## 7. Outcomes and Errors

Every command reports the existing outcomes (committed, invalid, stale,
missing, unavailable, uncertain). Field issues name the field
(`blocks`, `inUseFrom`, `shiftTypes[1].breaks`, ...). Nothing is retried
silently. Planner errors (no agreement on a date, ambiguous versions) show
on the affected days as **Unavailable** with the reason in Working.

## 8. Testing

- **Planner:** cycle-day arithmetic before and after `cycleStart`; cycles
  longer than a month; night shifts crossing midnight; Europe/Vilnius
  daylight-saving gap and overlap; version boundaries; one schedule per
  employment per date; each exception kind; Needs review after a version
  change; confirmed dates excluded.
- **Pay:** overtime windows (early start, late end, Changed day with and
  without a type change, extra with and without the flag, manual shift keeps the
  threshold); leave average window and fallback; sick 2-day rule including
  an illness starting on an Off day; reconciliation includes leave and
  excludes planned days.
- **Data:** Drift migration (new tables `work_schedules`,
  `work_schedule_shift_types`, `work_schedule_blocks`, `work_day_exceptions`,
  `work_leave_records`; shift link columns; running and on-break rows become
  drafts); `tool/schema_check.dart` updated; idempotent confirm.
- **Widgets:** schedule editor (blocks, reordering, shift types, preview,
  new-version prompt), calendar (keyboard, words on every entry), day
  actions, confirm dialog partial failure.
- **Integration:** create a 3-on/3-off/3-night/3-off rotation → confirm a
  week → mark a vacation day and a sick day → record a payslip → reconcile.
- **Goldens:** Calendar and Schedule properties at 1280 × 800 and 960 × 760.
- Synthetic data only.

## 9. Out of Scope

- Period-norm (summarized) overtime accounting.
- Shift swaps between people, team rosters, or importing rosters.
- Reminders or notifications.
- Leave balances (days remaining) and public-holiday leave rules.
- Any second visual style.
