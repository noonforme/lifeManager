from datetime import date

import pytest

from lifeos.habits.forms import HabitConfigurationForm
from lifeos.habits.models import Habit, HabitOccurrence

pytestmark = pytest.mark.django_db


def test_configuration_groups_cover_every_field_once(client):
    form = HabitConfigurationForm()
    fields = [field.name for section in form.sections for field in section['fields']]
    assert len(fields) == len(set(fields)) == len(form.fields)
    assert set(fields) == set(form.fields)
    html = client.get('/habits/new/').content.decode()
    for heading in ('Basics', 'Quantity target', 'Recurrence', 'Reminders', 'Optional exceptions'):
        assert f'<legend>{heading}</legend>' in html
    assert 'novalidate' in html
    assert 'habits-form' in html


def test_register_links_existing_evidence_to_correction(client):
    h = Habit.objects.create(name='Example', start_date=date(2024, 1, 1))
    o = HabitOccurrence.objects.create(habit=h, occurrence_date=date(2024, 1, 2), result='completed', note='private-history-marker')
    html = client.get('/habits/', {'date': '2024-01-02'}).content.decode()
    assert f'/habits/{h.pk}/occurrences/{o.pk}/edit/' in html
    assert 'Correct completion' in html
    assert 'private-history-marker' not in html
    assert 'habits-summary' in html
    assert 'datetime="2024-01-02"' in html


@pytest.mark.parametrize('kind,label', [('check', 'completion'), ('chore', 'chore outcome'), ('abstinence', 'abstinence outcome'), ('quantity', 'measurement')])
def test_outcome_entry_uses_type_specific_copy(client, kind, label):
    extras = {'unit': 'steps', 'target_rule': 'at_least', 'lower_target': 1} if kind == 'quantity' else {}
    h = Habit.objects.create(name='Example', habit_type=kind, start_date=date(2024, 1, 1), **extras)
    html = client.get(f'/habits/{h.pk}/occurrences/new/', {'date': '2024-01-02'}).content.decode()
    assert f'Record {label}' in html
    assert 'habits-form' in html
    assert 'Cancel' in html


def test_non_due_row_does_not_offer_standard_entry(client):
    h = Habit.objects.create(name='Example', start_date=date(2024, 2, 1))
    html = client.get('/habits/', {'date': '2024-01-02'}).content.decode()
    assert f'/habits/{h.pk}/occurrences/new/' not in html
    assert f'/habits/{h.pk}/' in html


def test_quantity_review_has_type_specific_entry_action(client):
    h = Habit.objects.create(name='Example', habit_type='quantity', unit='steps', target_rule='at_least', lower_target=1, start_date=date(2024, 1, 1))
    html = client.get(f'/habits/{h.pk}/').content.decode()
    assert 'Record measurement' in html


def test_attention_dates_link_to_dated_entry(client):
    h = Habit.objects.create(name='Example', start_date=date(2024, 1, 1))
    html = client.get('/habits/', {'date': '2024-01-03'}).content.decode()
    assert f'/habits/{h.pk}/occurrences/new/?date=2024-01-01' in html


def test_invalid_schedule_edit_retains_configuration_and_accessible_errors(client):
    from .test_habit_workflows import VALID
    response = client.post('/habits/new/', {**VALID, 'recurrence_kind': 'weekly', 'weekdays': ['0'], 'additions': '2024-02-01'})
    assert response.status_code == 302
    h = Habit.objects.get()
    response = client.post(f'/habits/{h.pk}/edit/', {**VALID, 'recurrence_kind': 'daily', 'weekdays': ['0'], 'additions': '2024-02-02'})
    assert response.status_code == 200
    h.refresh_from_db()
    assert h.recurrence_kind == 'weekly'
    assert h.components.get().value == 0
    assert h.exceptions.get().day == date(2024, 2, 1)
    html = response.content.decode()
    assert 'href="#id_weekdays"' in html
    assert 'id_weekdays_error' in html
    assert 'form-field--invalid' in html
    assert '2024-02-02' in html


def test_review_has_distinct_sections_and_supporting_pages_have_headers(client):
    h = Habit.objects.create(name='Example', start_date=date(2024, 1, 1))
    html = client.get(f'/habits/{h.pk}/').content.decode()
    for label in ('Current status', 'Configuration', 'Recorded outcomes'):
        assert label in html
    for path in (f'/habits/{h.pk}/archive/', '/habits/archived/'):
        response = client.get(path)
        assert response.status_code == 200
        assert 'page-header habits-header' in response.content.decode()
