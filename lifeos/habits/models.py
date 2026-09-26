from decimal import Decimal

from django.core.exceptions import ValidationError
from django.core.validators import MaxLengthValidator, MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models import F, Q

QUANTITY_MAX = Decimal("999999999.99")


class Habit(models.Model):
    class Type(models.TextChoices):
        CHECK = "check", "Check"
        QUANTITY = "quantity", "Quantity"
        ABSTINENCE = "abstinence", "Abstinence"
        CHORE = "chore", "Scheduled chore"

    class TargetRule(models.TextChoices):
        AT_LEAST = "at_least", "At least"
        AT_MOST = "at_most", "At most"
        RANGE = "range", "Inclusive range"

    name = models.CharField(max_length=120)
    description = models.TextField(blank=True, default="", max_length=500, validators=[MaxLengthValidator(500)])
    habit_type = models.CharField(max_length=10, choices=Type.choices, default=Type.CHECK)
    start_date = models.DateField()
    end_date = models.DateField(blank=True, null=True)
    reminder_time = models.TimeField(blank=True, null=True)
    reminder_text = models.CharField(max_length=160, blank=True, default="")
    is_archived = models.BooleanField(default=False)
    archived_at = models.DateTimeField(blank=True, null=True)
    unit = models.CharField(max_length=40, blank=True, default="")
    target_rule = models.CharField(max_length=8, blank=True, default="", choices=TargetRule.choices)
    lower_target = models.DecimalField(max_digits=11, decimal_places=2, blank=True, null=True,
                                      validators=[MinValueValidator(Decimal("0")), MaxValueValidator(QUANTITY_MAX)])
    upper_target = models.DecimalField(max_digits=11, decimal_places=2, blank=True, null=True,
                                      validators=[MinValueValidator(Decimal("0")), MaxValueValidator(QUANTITY_MAX)])
    recurrence_kind = models.CharField(max_length=24, default="daily", choices=[(x, x) for x in ("daily", "weekly", "interval", "monthly_dates", "monthly_ordinal_weekdays")])
    interval_n = models.PositiveIntegerField(default=1, validators=[MinValueValidator(1), MaxValueValidator(3650)])
    interval_unit = models.CharField(max_length=5, default="days", choices=[("days", "Days"), ("weeks", "Weeks")])
    anchor_date = models.DateField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("name", "pk")
        constraints = [
            models.CheckConstraint(condition=Q(interval_n__gte=1, interval_n__lte=3650), name="habits_interval_bounds"),
            models.CheckConstraint(condition=~Q(recurrence_kind="interval") | Q(anchor_date__isnull=False), name="habits_interval_anchor"),
            models.CheckConstraint(condition=Q(recurrence_kind__in=["daily","weekly","interval","monthly_dates","monthly_ordinal_weekdays"]), name="habits_recurrence_kind"),
            models.CheckConstraint(condition=Q(habit_type__in=["check", "quantity", "abstinence", "chore"]), name="habits_type_valid"),
            models.CheckConstraint(condition=Q(end_date__isnull=True) | Q(end_date__gte=F("start_date")), name="habits_active_range"),
            models.CheckConstraint(condition=(Q(is_archived=False, archived_at__isnull=True) | Q(is_archived=True, archived_at__isnull=False)), name="habits_archive_state"),
            models.CheckConstraint(condition=(
                Q(habit_type__in=["check", "abstinence", "chore"], unit="", target_rule="", lower_target__isnull=True, upper_target__isnull=True)
                | (Q(habit_type="quantity") & ~Q(unit="") & (
                    Q(target_rule="at_least", lower_target__isnull=False, upper_target__isnull=True)
                    | Q(target_rule="at_most", lower_target__isnull=True, upper_target__isnull=False)
                    | Q(target_rule="range", lower_target__isnull=False, upper_target__isnull=False, upper_target__gte=F("lower_target"))
                ))), name="habits_quantity_configuration"),
            models.CheckConstraint(condition=Q(lower_target__isnull=True) | Q(lower_target__gte=0, lower_target__lte=QUANTITY_MAX), name="habits_lower_target_bounds"),
            models.CheckConstraint(condition=Q(upper_target__isnull=True) | Q(upper_target__gte=0, upper_target__lte=QUANTITY_MAX), name="habits_upper_target_bounds"),
        ]

    def clean_fields(self, exclude=None):
        for name in ("name", "description", "reminder_text", "unit"):
            setattr(self, name, (getattr(self, name) or "").strip())
        for name in ("lower_target", "upper_target"):
            value = getattr(self, name)
            if value is not None and (not isinstance(value, Decimal) or not value.is_finite()
                                      or value.as_tuple().exponent > 0 or value.as_tuple().exponent < -2):
                raise ValidationError({name: "Enter a non-negative decimal with at most two decimal places."})
        super().clean_fields(exclude=exclude)

    def clean(self):
        errors = {}
        if self.recurrence_kind == "interval" and self.anchor_date is None:
            errors["anchor_date"] = "An interval requires an anchor date."
        if self.end_date is not None and self.start_date is not None and self.end_date < self.start_date:
            errors["end_date"] = "End date cannot precede start date."
        if self.is_archived != (self.archived_at is not None):
            errors["is_archived"] = "Archived state requires an archive timestamp."
        if self.habit_type != self.Type.QUANTITY:
            if self.unit or self.target_rule or self.lower_target is not None or self.upper_target is not None:
                errors["unit"] = "Only quantity habits have quantity configuration."
        else:
            if not self.unit:
                errors["unit"] = "Enter a unit."
            lower, upper = self.lower_target, self.upper_target
            if self.target_rule == self.TargetRule.AT_LEAST:
                valid = lower is not None and upper is None
            elif self.target_rule == self.TargetRule.AT_MOST:
                valid = lower is None and upper is not None
            elif self.target_rule == self.TargetRule.RANGE:
                valid = lower is not None and upper is not None and lower.is_finite() and upper.is_finite() and lower <= upper
            else:
                valid = False
            if not valid:
                errors["target_rule"] = "Supply only the targets required by the selected rule."
        if self.pk and hasattr(self, "occurrences") and self.occurrences.exists():
            original_type = type(self).objects.values_list("habit_type", flat=True).get(pk=self.pk)
            if original_type != self.habit_type:
                errors["habit_type"] = "Habit type cannot change after occurrence history exists."
        if errors:
            raise ValidationError(errors)


class RecurrenceComponent(models.Model):
    habit = models.ForeignKey(Habit, on_delete=models.PROTECT, related_name="components")
    kind = models.CharField(max_length=12, choices=[("weekday", "Weekday"), ("month_day", "Month date"), ("ordinal", "Ordinal weekday")])
    value = models.PositiveSmallIntegerField()
    ordinal = models.SmallIntegerField(default=0)

    class Meta:
        constraints = [models.UniqueConstraint(fields=("habit", "kind", "value", "ordinal"), name="habits_component_unique"), models.CheckConstraint(condition=Q(kind="weekday", value__gte=0, value__lte=6, ordinal=0) | Q(kind="month_day", value__gte=1, value__lte=31, ordinal=0) | Q(kind="ordinal", value__gte=0, value__lte=6, ordinal__in=[-1,1,2,3,4]), name="habits_component_valid")]


    def clean(self):
        expected = {"weekly": "weekday", "monthly_dates": "month_day", "monthly_ordinal_weekdays": "ordinal"}.get(self.habit.recurrence_kind)
        if self.kind != expected:
            raise ValidationError("This component does not apply to the habit recurrence.")

    def save(self, *args, **kwargs):
        self.clean_fields()
        self.clean()
        return super().save(*args, **kwargs)


class ScheduleException(models.Model):
    habit = models.ForeignKey(Habit, on_delete=models.PROTECT, related_name="exceptions")
    day = models.DateField()
    kind = models.CharField(max_length=9, choices=[("addition", "Addition"), ("exclusion", "Exclusion")])

    class Meta:
        constraints = [models.UniqueConstraint(fields=("habit", "day"), name="habits_exception_unique"), models.CheckConstraint(condition=Q(kind__in=["addition","exclusion"]), name="habits_exception_kind")]


class HabitPause(models.Model):
    habit = models.ForeignKey(Habit, on_delete=models.PROTECT, related_name="pauses")
    start_date = models.DateField()
    end_date = models.DateField()

    class Meta:
        constraints = [models.CheckConstraint(condition=Q(end_date__gte=F("start_date")), name="habits_pause_range")]

    def clean(self):
        if self.start_date and self.end_date and self.end_date < self.start_date:
            raise ValidationError({"end_date": "End date cannot precede start date."})


class HabitArchivePeriod(models.Model):
    habit = models.ForeignKey(Habit, on_delete=models.PROTECT, related_name="archive_periods")
    start_date = models.DateField()
    end_date = models.DateField(null=True, blank=True)

    class Meta:
        constraints = [models.CheckConstraint(condition=Q(end_date__isnull=True) | Q(end_date__gte=F("start_date")), name="habits_archive_period_range"), models.UniqueConstraint(fields=("habit",), condition=Q(end_date__isnull=True), name="habits_one_open_archive")]


class HabitOccurrence(models.Model):
    habit = models.ForeignKey(Habit, on_delete=models.PROTECT, related_name="occurrences")
    occurrence_date = models.DateField()
    result = models.CharField(max_length=10, blank=True, default="", choices=[(x,x.title()) for x in ("completed","missed","successful","lapse","excused")])
    value = models.DecimalField(max_digits=11, decimal_places=2, blank=True, null=True, validators=[MinValueValidator(Decimal("0")), MaxValueValidator(QUANTITY_MAX)])
    note = models.TextField(blank=True, default="", max_length=500, validators=[MaxLengthValidator(500)])
    excuse_reason = models.CharField(blank=True, default="", max_length=250)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-occurrence_date", "-created_at", "-pk")
        constraints = [models.UniqueConstraint(fields=("habit","occurrence_date"), name="habits_occurrence_unique"), models.CheckConstraint(condition=Q(result__in=["completed","missed","successful","lapse","excused"],value__isnull=True) | Q(result="",value__isnull=False,value__gte=0,value__lte=QUANTITY_MAX),name="habits_occurrence_evidence"), models.CheckConstraint(condition=Q(result="excused") | Q(excuse_reason=""),name="habits_reason_only_excused")]

    def clean_fields(self, exclude=None):
        self.note = (self.note or "").strip()
        self.excuse_reason = (self.excuse_reason or "").strip()
        if self.value is not None and (not self.value.is_finite() or self.value.as_tuple().exponent > 0 or self.value.as_tuple().exponent < -2):
            raise ValidationError({"value": "Enter a non-negative decimal with at most two decimal places."})
        super().clean_fields(exclude=exclude)

    def save(self, *args, **kwargs):
        self.clean_fields()
        self.clean()
        return super().save(*args, **kwargs)

    def clean(self):
        if not self.habit_id:
            return
        kind = self.habit.habit_type
        allowed = {"check": {"completed","missed","excused"},"chore": {"completed","missed","excused"},"abstinence": {"successful","lapse","excused"},"quantity": {"","excused"}}[kind]
        if self.result not in allowed or (kind == "quantity" and ((self.result == "") != (self.value is not None))) or (kind != "quantity" and self.value is not None):
            raise ValidationError("Choose evidence appropriate to this habit type.")
        if self.result != "excused" and self.excuse_reason:
            raise ValidationError({"excuse_reason": "A reason is only valid for an excused result."})
