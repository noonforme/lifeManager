# Era Date and Time Pickers Design

Status: approved in conversation on 2026-10-03; written for review.

## 1. Purpose

Every date in LifeOS is typed as `YYYY-MM-DD` and every time as `HH:MM` in
plain text fields. The owner wants to pick them instead, in controls that look
and behave like the 2001-era Date/Time Picker, everywhere a date or time is
entered. The schedule screens of Work Schedules Part 2 reuse the same
controls.

## 2. Decisions

| Question | Decision |
|---|---|
| Scope | Every date and time field in the app (section 4). |
| Input | Dates are pick only: they come from the month calendar. Times: spin buttons, arrow keys, or digits typed into the selected part (amended 2026-10-07 at the owner's request; the era's picker took typed digits). |
| Approach | Own era controls painted from LifeOS tokens (not Material pickers, not a calendar dialog). |
| Date format in the box | `Mon 2026-10-05`: weekday, then the app's ISO date. |
| Week start | Monday. |
| Optional dates | An era check box inside the box; unticked means none. |
| Seconds | Shown only when the value has them; new times are whole minutes. |

## 3. Controls

All three live in `lib/shared/workbench/`, take colours from
`LifeOSTokens`/`MillenniumColors`, and paint the drop arrow, ◂ ▸ and ▴▾ with
`EraGlyph` (the bundled font lacks those glyphs).

### 3.1 Date box (`era_date_field.dart`, `EraDateField`)

- A label in Body type above a white box with the field-line border, like
  `EraField`. The box shows the date as `Mon 2026-10-05` in the figure face,
  with the blue drop-arrow button of `EraComboFace` on the right.
- Clicking the box, or Space, Enter or Alt+↓ while it has focus, opens the
  month calendar below the box; it opens above when there is no room below.
- Enter picks the highlighted day and closes; Esc or a click outside closes
  without a change. Focus returns to the box.
- **Optional dates** (`optional: true`): an era check box sits inside the box
  on the left. Unticked, the date text is muted and the value is `null`.
  Ticking it restores the last date shown, or today when there was none. The
  drop arrow is disabled while unticked.
- Inputs: `label`, `value` (`LocalDate?`), `onChanged`, `optional`, `today`
  (for the circle and the defaults), `error`, `fieldKey`.
- Errors render under the box as in `EraField`.

### 3.2 Month calendar (`era_month_calendar.dart`, `EraMonthCalendar`)

- Header: ◂ `October 2026` ▸ on the head colour band.
- A grid of weekday initials (Mo Tu We Th Fr Sa Su) and six weeks of days,
  weeks starting on Monday. Days of the previous and next months are muted.
  Today has a red circle; the chosen day is filled with selection blue with
  selection ink. The keyboard cursor is the dotted focus rectangle.
- Footer link: `Today: 2026-10-05`, which picks today.
- Keys: arrows move one day or one week; PageUp/PageDown move one month;
  Shift+PageUp/PageDown move one year; Home/End go to the first/last day of
  the month; Enter or Space picks; Esc cancels. Moving past the shown month
  pages the calendar.
- A day that does not exist in the target month clamps (31 January +1 month
  is 28 or 29 February).
- Usable on its own (Part 2's Calendar view can reuse the grid).

### 3.3 Time box (`era_time_field.dart`, `EraTimeField`)

- A label above a white box showing `07:00`, with stacked ▴▾ spin buttons on
  the right.
- Clicking the hours or the minutes selects that part, filled with selection
  blue; ← and → move between parts. The hours are selected when the box gets
  focus.
- ▴▾ and Up/Down step the selected part by 1; PageUp/PageDown by 10. Values
  wrap: 23 → 00 for hours, 59 → 00 for minutes, without carrying into the
  other part.
- Holding a spin button repeats after 400 ms, then every 60 ms.
- **Seconds:** when the value has seconds, a third part `:13` is shown and can
  be selected and stepped the same way. Values without seconds never gain
  them.
- **Empty:** a box may start empty (`value: null`), showing `--:--`. The first
  step sets it to `emptyStart` (for a break, the shift's start time), then
  steps from there.
- Inputs: `label`, `value` (`LocalTime?`), `onChanged`, `emptyStart`,
  `error`, `fieldKey`, `semanticLabel`.

### 3.4 Accessibility

- Each box is one semantics node named by its label, its value and, when
  present, its error: "Starts on, Monday 5 October 2026".
- The date box is a button that opens the calendar. Each calendar day is
  labelled with its full date, and the chosen day is marked as selected.
- The time box exposes increase and decrease actions for the selected part.
- Targets are at least 24 × 24 px. The boxes and the open calendar hold at
  200 % text, wrapping rather than clipping.

## 4. Where they go

The existing field keys stay on the new boxes.

| Form | Dates | Times | Initial values |
|---|---|---|---|
| Agreement (`employment_agreement_forms.dart`) | Starts on; Ends on (optional) | Night pay from / to | Starts today or the saved date; end unticked or saved; night 22:00–06:00 or saved |
| Pay period (`period_payslip_forms.dart`) | Start, End | none | First and last day of today's month |
| Payslip (`period_payslip_forms.dart`) | Issued; Paid (optional) | none | Issued today; paid unticked |
| Work › Date range… (`work_toolbar_controls.dart`) | From, To | none | The current range, otherwise the first of this month to today |
| Manual shift, correction and draft revision (`shift_forms.dart`) | Start date, End date | Start, End | Prefill, else today; the end date follows the start date until changed |
| Each break (`shift_forms.dart`) | Start date, End date | Start, End | The shift's start date; times empty (`--:--`) until set |

- Forms hold `LocalDate`/`LocalTime` values in state instead of text
  controllers for these fields. Timezone, note, label and money fields stay
  typed.
- The parse messages "Enter a date as YYYY-MM-DD." and "Enter a time as
  HH:MM." are removed: picked values are always well-formed. Real checks stay:
  an end before its start, a night window whose start equals its end,
  agreement dates overlapping another agreement, and a break outside its
  shift.
- A break whose times are both empty is ignored, as an empty break is today.
- The shift form's daylight-saving fold choices are unchanged.

## 5. Testing

Tests are written first and watched failing.

- **Date box:** shows `Mon 2026-10-05`; opens on click, Space, Enter and
  Alt+↓; Enter picks and Esc or an outside click cancels; focus returns to
  the box; the optional check box gives `null` when unticked and restores the
  last date or today when ticked; the drop arrow is disabled while unticked.
- **Calendar:** arrows, PageUp/PageDown, Shift+PageUp/PageDown and Home/End
  move as specified; paging across a year end; 29 February in a leap year and
  clamping from 31 January; Monday-first weeks; today circled; outside days
  muted; the Today link picks today.
- **Time box:** clicking selects a part; ←/→ switch parts; ▴▾, Up/Down and
  PageUp/PageDown step and wrap without carrying; holding a spin button
  repeats (fake async); seconds appear only for values with seconds; an empty
  box shows `--:--` and its first step uses `emptyStart`.
- **Semantics:** one labelled node per box with the full value; calendar days
  labelled; increase/decrease actions on the time box.
- **Layout:** both controls and the open calendar at 200 % text; the calendar
  opens above the box near the bottom of the window.
- **Forms:** each form in section 4 submits the values picked; the removed
  parse messages no longer appear; the remaining checks still refuse.
- **Test helpers:** `pickDate(tester, key, date)` and
  `setTime(tester, key, time)` in `test/support/` drive the real controls
  (open, page to the month, choose the day; select a part and step). Every
  `enterText` on a date or time field in the suite moves to these helpers.
- **Goldens:** the open calendar and the agreement form at 1280 × 800 and
  960 × 760, plus the existing real-font check.
- `./app.sh` tests and checks pass.

## 6. Out of Scope

- Typing into date or time boxes.
- Time zones in the boxes (the shift form's timezone field stays typed).
- Date ranges in one control; ranges stay two date boxes.
- Localised month and weekday names (English, as the rest of the app).
