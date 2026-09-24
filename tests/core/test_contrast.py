import pytest

from lifeos.core.contrast import contrast_ratio


@pytest.mark.parametrize(
    ("foreground", "background"),
    [
        ("#171a18", "#f4f1e8"), ("#59625d", "#f4f1e8"),
        ("#b73a22", "#ffffff"), ("#293000", "#ddf55a"),
        ("#00788a", "#f4f1e8"), ("#8a5a00", "#f4f1e8"),
        ("#577000", "#f4f1e8"), ("#f4f1e8", "#171d19"),
        ("#b8c0ba", "#171d19"), ("#21100c", "#ff765c"),
        ("#182000", "#c8ef45"), ("#4fd6e8", "#171d19"),
        ("#f4b64e", "#171d19"), ("#b8e85a", "#171d19"),
    ],
)
def test_normal_text_tokens_meet_aa(foreground: str, background: str) -> None:
    assert contrast_ratio(foreground, background) >= 4.5


@pytest.mark.parametrize(
    ("foreground", "background"),
    [
        ("#838c86", "#f4f1e8"),
        ("#171a18", "#f4f1e8"),
        ("#f4f1e8", "#202521"),
        ("#ffffff", "#b73a22"),
        ("#7c8b83", "#171d19"),
        ("#f4f1e8", "#171d19"),
        ("#f4f1e8", "#090c0a"),
        ("#21100c", "#ff765c"),
    ],
)
def test_boundary_and_focus_tokens_meet_non_text_contrast(foreground: str, background: str) -> None:
    assert contrast_ratio(foreground, background) >= 3.0


def test_light_global_focus_token_fails_on_rail_background() -> None:
    assert contrast_ratio("#171a18", "#202521") < 3.0


def test_black_and_white_have_maximum_contrast() -> None:
    assert contrast_ratio("#000000", "#ffffff") == pytest.approx(21.0)
