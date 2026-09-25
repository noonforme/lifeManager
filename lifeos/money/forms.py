import re
from decimal import Decimal

from django import forms

from .models import Transaction

MONEY_PATTERN = re.compile(r"^(?:0|[1-9]\d*)(?:\.\d{1,2})?$")


class StrictMoneyDecimalField(forms.DecimalField):
    def to_python(self, value):
        if isinstance(value, str) and not MONEY_PATTERN.fullmatch(value):
            raise forms.ValidationError(
                "Enter a positive euro amount with at most two decimal places."
            )
        return super().to_python(value)


class TransactionForm(forms.ModelForm):
    amount = StrictMoneyDecimalField(
        min_value=Decimal("0.01"),
        max_value=Decimal("999999999.99"),
        max_digits=11,
        decimal_places=2,
    )

    def full_clean(self):
        super().full_clean()
        for name, field in self.fields.items():
            described_by = [f"id_{name}_hint"]
            if name in self.errors:
                field.widget.attrs["aria-invalid"] = "true"
                described_by.append(f"id_{name}_error")
            field.widget.attrs["aria-describedby"] = " ".join(described_by)

    class Meta:
        model = Transaction
        fields = ("transaction_date", "direction", "amount", "category", "note")
        widgets = {
            "transaction_date": forms.DateInput(attrs={"type": "date"}),
            "amount": forms.NumberInput(attrs={"step": "0.01"}),
            "note": forms.Textarea(attrs={"rows": 5}),
        }
        help_texts = {
            "transaction_date": "The local calendar date for this transaction.",
            "direction": "Choose whether money came in or went out.",
            "amount": "Enter a positive euro amount with at most two decimal places.",
            "category": "Required plain text, up to 80 characters.",
            "note": "Optional plain text, up to 500 characters.",
        }
