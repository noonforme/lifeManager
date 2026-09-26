import re
from datetime import date
from decimal import Decimal

from django import forms

from .models import Habit, HabitPause, RecurrenceComponent, ScheduleException
from .recurrence import ScheduleInput


class StrictDecimalField(forms.DecimalField):
    def to_python(self, value):
        if isinstance(value,str) and value and not re.fullmatch(r"(?:0|[1-9][0-9]*)(?:\.[0-9]{1,2})?",value):
            raise forms.ValidationError("Enter a non-negative decimal with at most two decimal places.")
        return super().to_python(value)


class AccessibleForm:
    def full_clean(self):
        super().full_clean()
        for name,field in self.fields.items():
            references = [f"id_{name}_hint"]
            if name in self.errors:
                references.append(f"id_{name}_error")
                field.widget.attrs["aria-invalid"] = "true"
            field.widget.attrs["aria-describedby"] = " ".join(references)


def parse_dates(value):
    result = []
    for token in value.split(","):
        token = token.strip()
        if not token:
            continue
        if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}",token):
            raise ValueError
        result.append(date.fromisoformat(token))
    return tuple(sorted(set(result)))


class HabitConfigurationForm(AccessibleForm, forms.ModelForm):
    lower_target = StrictDecimalField(required=False,min_value=Decimal("0"),max_value=Decimal("999999999.99"),max_digits=11,decimal_places=2)
    upper_target = StrictDecimalField(required=False,min_value=Decimal("0"),max_value=Decimal("999999999.99"),max_digits=11,decimal_places=2)
    weekdays = forms.MultipleChoiceField(required=False,choices=list(enumerate(("Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"))))
    month_days = forms.MultipleChoiceField(required=False,choices=[(n,str(n)) for n in range(1,32)])
    ordinal_weekdays = forms.MultipleChoiceField(required=False,choices=[(f"{o}:{w}",f"{label} {day}") for o,label in ((1,"First"),(2,"Second"),(3,"Third"),(4,"Fourth"),(-1,"Last")) for w,day in enumerate(("Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"))])
    additions = forms.CharField(required=False,help_text="Added dates, comma-separated YYYY-MM-DD.")
    exclusions = forms.CharField(required=False,help_text="Excluded dates, comma-separated YYYY-MM-DD.")
    pause_ranges = forms.CharField(required=False,widget=forms.Textarea(attrs={"rows":3}),help_text="One inclusive YYYY-MM-DD/YYYY-MM-DD pause per line.")

    class Meta:
        model = Habit
        fields = ("name","description","habit_type","start_date","end_date","reminder_time","reminder_text","unit","target_rule","lower_target","upper_target","recurrence_kind","interval_n","interval_unit","anchor_date")
        widgets = {"start_date":forms.DateInput(attrs={"type":"date"}),"end_date":forms.DateInput(attrs={"type":"date"}),"anchor_date":forms.DateInput(attrs={"type":"date"}),"reminder_time":forms.TimeInput(attrs={"type":"time"}),"description":forms.Textarea(attrs={"rows":3})}

    def __init__(self,*args,**kwargs):
        super().__init__(*args,**kwargs)
        self.fields["target_rule"].choices = [("","Not a quantity habit"),*Habit.TargetRule.choices]
        self.fields["recurrence_kind"].choices = [("daily", "Every day"), ("weekly", "Selected weekdays"), ("interval", "Every N days or weeks"), ("monthly_dates", "Selected dates each month"), ("monthly_ordinal_weekdays", "First or last weekdays each month")]
        hints = {
            "name": "A short, recognizable name. Up to 120 characters.",
            "description": "Optional context for your routine. Up to 500 characters.",
            "habit_type": "Check: completion. Quantity: a measurement. Abstinence: success or lapse. Chore: a scheduled task.",
            "start_date": "First eligible local date, including this day.",
            "end_date": "Optional last eligible date, including this day.",
            "unit": "Quantity only: steps, minutes, glasses, or another unit.",
            "lower_target": "Quantity only: minimum for At least, or the lower end of a range.",
            "upper_target": "Quantity only: maximum for At most, or the upper end of a range.",
            "interval_n": "Interval only: 1–3650. Leave the default 1 for other schedules.",
            "interval_unit": "Interval only: count days or weeks from the anchor.",
            "anchor_date": "Interval only: the first date in the repeating sequence.",
            "weekdays": "Weekly only. Select one or more weekdays.",
            "month_days": "Monthly dates only. Dates absent from a month are skipped.",
            "ordinal_weekdays": "Monthly ordinal weekdays only. Select one or more combinations.",
            "reminder_time": "Optional local time, displayed in the app only.",
            "reminder_text": "Optional reminder text. Up to 160 characters.",
        }
        for name, hint in hints.items():
            self.fields[name].help_text = hint
        if self.instance.pk:
            for kind,field in (("weekday","weekdays"),("month_day","month_days"),("ordinal","ordinal_weekdays")):
                self.initial[field] = [f"{c.ordinal}:{c.value}" if kind=="ordinal" else str(c.value) for c in self.instance.components.all() if c.kind==kind]
            for kind,field in (("addition","additions"),("exclusion","exclusions")):
                self.initial[field] = ", ".join(e.day.isoformat() for e in self.instance.exceptions.all() if e.kind==kind)
            self.initial["pause_ranges"] = "\n".join(f"{p.start_date.isoformat()}/{p.end_date.isoformat()}" for p in self.instance.pauses.all())
        for field in self.fields.values():
            if not field.help_text:
                field.help_text = "Optional." if not field.required else "Required."

    @property
    def sections(self):
        groups = (
            ("Basics", "Choose the outcome you want to track. Type cannot change once recorded history exists.", ("name", "description", "habit_type", "start_date", "end_date")),
            ("Quantity target", "For quantity habits only; leave these fields blank for other types. At least uses the lower target, at most uses the upper target, and a range uses both.", ("unit", "target_rule", "lower_target", "upper_target")),
            ("Recurrence", "Daily needs no selections. Weekly uses weekdays; monthly dates uses month days; monthly ordinal weekdays uses first/last weekday selections. Interval uses number, unit and anchor. Clear selections that do not apply when changing recurrence.", ("recurrence_kind", "interval_n", "interval_unit", "anchor_date", "weekdays", "month_days", "ordinal_weekdays")),
            ("Reminders", "Shown in LifeOS only; no notifications are sent.", ("reminder_time", "reminder_text")),
            ("Optional exceptions", "Add individual dates, exclude dates, or suspend an inclusive period. Additions cannot override pauses, exclusions or the active date range.", ("additions", "exclusions", "pause_ranges")),
        )
        return tuple({"title": title, "instruction": instruction, "fields": tuple(self[name] for name in names)} for title, instruction, names in groups)

    def clean(self):
        data = super().clean()
        if self.errors:
            return data
        kind = data["recurrence_kind"]
        for field,owner in (("weekdays","weekly"),("month_days","monthly_dates"),("ordinal_weekdays","monthly_ordinal_weekdays")):
            if kind != owner and data.get(field):
                self.add_error(field,"This component does not apply to the selected recurrence.")
        if self.errors:
            return data
        try:
            pauses = []
            for line in data["pause_ranges"].splitlines():
                if line.strip():
                    a,b = line.strip().split("/")
                    pauses.append((parse_dates(a)[0],parse_dates(b)[0]))
            self.schedule = ScheduleInput(start_date=data["start_date"],end_date=data["end_date"],kind=kind,interval_n=data["interval_n"],interval_unit=data["interval_unit"],anchor_date=data["anchor_date"],weekdays=tuple(int(x) for x in data["weekdays"]),month_days=tuple(int(x) for x in data["month_days"]),ordinal_weekdays=tuple(tuple(int(n) for n in x.split(":")) for x in data["ordinal_weekdays"]),additions=parse_dates(data["additions"]),exclusions=parse_dates(data["exclusions"]),pauses=tuple(pauses))
        except (ValueError,IndexError):
            raise forms.ValidationError("Check recurrence components, exact dates and non-contradictory exceptions.")
        return data

    def save(self):
        item = super().save()
        item.components.all().delete()
        item.exceptions.all().delete()
        item.pauses.all().delete()
        for kind,values in (("weekday",self.schedule.weekdays),("month_day",self.schedule.month_days)):
            for value in set(values):
                RecurrenceComponent.objects.create(habit=item,kind=kind,value=value)
        for ordinal,value in set(self.schedule.ordinal_weekdays):
            RecurrenceComponent.objects.create(habit=item,kind="ordinal",value=value,ordinal=ordinal)
        for kind,values in (("addition",self.schedule.additions),("exclusion",self.schedule.exclusions)):
            for day in values:
                ScheduleException.objects.create(habit=item,kind=kind,day=day)
        for start,end in self.schedule.pauses:
            HabitPause.objects.create(habit=item,start_date=start,end_date=end)
        return item


class OccurrenceForm(AccessibleForm, forms.ModelForm):
    value = StrictDecimalField(required=False,min_value=Decimal("0"),max_value=Decimal("999999999.99"),max_digits=11,decimal_places=2)
    one_off = forms.BooleanField(required=False,help_text="Explicitly add this non-due date. Active range, pauses, exclusions and archive periods still apply.")

    class Meta:
        from .models import HabitOccurrence
        model = HabitOccurrence
        fields = ("occurrence_date","result","value","note","excuse_reason")
        widgets = {"occurrence_date":forms.DateInput(attrs={"type":"date"}),"note":forms.Textarea(attrs={"rows":3})}

    def __init__(self,*args,habit,**kwargs):
        super().__init__(*args,**kwargs)
        self.habit = habit
        self.instance.habit = habit
        outcome = {"check": "completion", "chore": "chore outcome", "abstinence": "abstinence outcome", "quantity": "measurement"}[habit.habit_type]
        self.title = f"{'Correct' if self.instance.pk else 'Record'} {outcome}"
        self.instruction = {
            "check": "Record completion, a missed result, or an excused outcome. No result is inferred from silence.",
            "chore": "Record whether the scheduled chore was completed, missed, or excused.",
            "abstinence": "Record a successful day, a lapse, or an excused outcome. Missing evidence is never counted as success.",
            "quantity": "Enter the measured amount; LifeOS compares it with the configured target. Choose Excused instead when no measurement applies.",
        }[habit.habit_type]
        self.fields["occurrence_date"].help_text = "The local date this outcome belongs to. Corrections keep the original date."
        self.fields["result"].label = "Outcome"
        self.fields["result"].help_text = self.instruction
        self.fields["value"].label = f"Amount ({habit.unit})" if habit.unit else "Amount"
        self.fields["note"].help_text = "Optional factual context. Up to 500 characters."
        self.fields["excuse_reason"].help_text = "Optional, only for an excused outcome. Up to 250 characters."
        allowed = {"check": ("completed","missed","excused"),"chore": ("completed","missed","excused"),"abstinence": ("successful","lapse","excused"),"quantity": ("","excused")}[habit.habit_type]
        self.fields["result"].choices = [(x,x.title() if x else "Measured quantity") for x in allowed]
        self.fields["result"].required = habit.habit_type != "quantity"
        if habit.habit_type != "quantity":
            self.fields.pop("value")
        if self.instance.pk:
            self.fields["occurrence_date"].disabled = True
            self.fields.pop("one_off")
        for f in self.fields.values():
            if not f.help_text:
                f.help_text = "Optional." if not f.required else "Required."

    def clean(self):
        from dataclasses import replace
        from .queries import schedule_for
        from .recurrence import is_due
        data = super().clean()
        if self.errors or "occurrence_date" not in data:
            return data
        if not self.instance.pk:
            schedule = schedule_for(self.habit)
            day = data["occurrence_date"]
            self.existing_occurrence = self.habit.occurrences.filter(occurrence_date=day).first()
            if self.existing_occurrence:
                raise forms.ValidationError("A result already exists for this date. Use the explicit correction workflow.")
            if self.habit.is_archived:
                raise forms.ValidationError("Restore this habit before recording a new result.")
            if not is_due(schedule,day):
                if not data.get("one_off") or not is_due(replace(schedule,additions=tuple(set(schedule.additions) | {day})),day):
                    raise forms.ValidationError("Choose a due date or explicitly add an eligible one-off date.")
        return data
