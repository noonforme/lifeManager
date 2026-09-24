from django import forms

from .models import Shift


class ShiftForm(forms.ModelForm):
    def full_clean(self):
        super().full_clean()
        for name, field in self.fields.items():
            described_by = [f"id_{name}_hint"]
            if name in self.errors:
                field.widget.attrs["aria-invalid"] = "true"
                described_by.append(f"id_{name}_error")
            field.widget.attrs["aria-describedby"] = " ".join(described_by)

    class Meta:
        model = Shift
        fields = (
            "work_date",
            "shift_type",
            "worked_hours",
            "overtime_hours",
            "hourly_rate",
            "note",
        )
        widgets = {
            "work_date": forms.DateInput(attrs={"type": "date"}),
            "worked_hours": forms.NumberInput(attrs={"step": "0.01"}),
            "overtime_hours": forms.NumberInput(attrs={"step": "0.01"}),
            "hourly_rate": forms.NumberInput(attrs={"step": "0.01"}),
            "note": forms.Textarea(attrs={"rows": 5}),
        }
        help_texts = {
            "work_date": "The local calendar date for this shift.",
            "shift_type": "Shift type is descriptive and does not change pay.",
            "worked_hours": "Enter more than 0 and no more than 24 hours.",
            "overtime_hours": "Enter 0 through 24 hours.",
            "hourly_rate": "Enter the hourly rate from 0 through 10000.",
            "note": "Optional plain text, up to 500 characters.",
        }
