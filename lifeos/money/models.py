from decimal import Decimal

from django.core.exceptions import ValidationError
from django.core.validators import (
    MaxLengthValidator,
    MaxValueValidator,
    MinValueValidator,
)
from django.db import models
from django.db.models import Q


class Transaction(models.Model):
    class Direction(models.TextChoices):
        INCOME = "income", "Income"
        EXPENSE = "expense", "Expense"

    transaction_date = models.DateField()
    direction = models.CharField(max_length=7, choices=Direction.choices)
    amount = models.DecimalField(
        max_digits=11,
        decimal_places=2,
        validators=[
            MinValueValidator(Decimal("0.01")),
            MaxValueValidator(Decimal("999999999.99")),
        ],
    )
    category = models.CharField(max_length=80)
    note = models.TextField(
        blank=True,
        default="",
        max_length=500,
        validators=[MaxLengthValidator(500)],
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-transaction_date", "-created_at", "-pk")
        constraints = [
            models.CheckConstraint(
                condition=Q(amount__gte=Decimal("0.01")),
                name="money_transaction_amount_min",
            ),
            models.CheckConstraint(
                condition=Q(amount__lte=Decimal("999999999.99")),
                name="money_transaction_amount_max",
            ),
        ]

    def clean_fields(self, exclude=None):
        self.category = (self.category or "").strip()
        self.note = (self.note or "").strip()
        super().clean_fields(exclude=exclude)
        if self.amount is not None and (
            not self.amount.is_finite() or self.amount.as_tuple().exponent > 0
        ):
            raise ValidationError(
                {"amount": "Enter a positive euro amount with at most two decimal places."}
            )
