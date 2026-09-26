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
        if self.instance.pk:
            for kind,field in (("weekday","weekdays"),("month_day","month_days"),("ordinal","ordinal_weekdays")):
                self.initial[field] = [f"{c.ordinal}:{c.value}" if kind=="ordinal" else str(c.value) for c in self.instance.components.all() if c.kind==kind]
            for kind,field in (("addition","additions"),("exclusion","exclusions")):
                self.initial[field] = ", ".join(e.day.isoformat() for e in self.instance.exceptions.all() if e.kind==kind)
            self.initial["pause_ranges"] = "\n".join(f"{p.start_date.isoformat()}/{p.end_date.isoformat()}" for p in self.instance.pauses.all())
        for field in self.fields.values():
            if not field.help_text:
                field.help_text = "Optional." if not field.required else "Required."

    def clean(self):
        data = super().clean()
        if self.errors:
            return data
        kind = data["recurrence_kind"]
        for field,owner in (("weekdays","weekly"),("month_days","monthly_dates"),("ordinal_weekdays","monthly_ordinal_weekdays")):
            if kind != owner and data.get(field):
                self.add_error(field,"This component does not apply to the selected recurrence.")
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
