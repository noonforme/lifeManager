from decimal import Decimal

from django.core.validators import (
    MaxLengthValidator,
    MaxValueValidator,
    MinValueValidator,
)
from django.db import models
from django.db.models import Q


class Shift(models.Model):
    class Type(models.TextChoices):
        NORMAL = "normal", "Normal"
        NIGHT = "night", "Night"
        HOLIDAY = "holiday", "Holiday"

    work_date = models.DateField()
    shift_type = models.CharField(max_length=7, choices=Type.choices)
    worked_hours = models.DecimalField(
        max_digits=4,
        decimal_places=2,
        validators=[
            MinValueValidator(Decimal("0.01")),
            MaxValueValidator(Decimal("24.00")),
        ],
    )
    overtime_hours = models.DecimalField(
        max_digits=4,
        decimal_places=2,
        validators=[
            MinValueValidator(Decimal("0.00")),
            MaxValueValidator(Decimal("24.00")),
        ],
    )
    hourly_rate = models.DecimalField(
        max_digits=7,
        decimal_places=2,
        validators=[
            MinValueValidator(Decimal("0.00")),
            MaxValueValidator(Decimal("10000.00")),
        ],
    )
    note = models.TextField(
        blank=True,
        default="",
        max_length=500,
        validators=[MaxLengthValidator(500)],
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-work_date", "-created_at", "-pk")
        constraints = [
            models.CheckConstraint(
                condition=Q(worked_hours__gt=0, worked_hours__lte=24),
                name="work_shift_worked_hours_range",
            ),
            models.CheckConstraint(
                condition=Q(overtime_hours__gte=0, overtime_hours__lte=24),
                name="work_shift_overtime_hours_range",
            ),
            models.CheckConstraint(
                condition=Q(hourly_rate__gte=0, hourly_rate__lte=10000),
                name="work_shift_hourly_rate_range",
            ),
        ]

    def clean_fields(self, exclude=None):
        self.note = (self.note or "").strip()
        super().clean_fields(exclude=exclude)
