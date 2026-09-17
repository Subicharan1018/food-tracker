from app.services.pacing_service import detect_gaps, expected_fraction_by_hour


def test_no_issue_day_does_not_trigger_an_alert():
    diary = [{"foodName": "eggs", "proteinG": 155, "portionQty": 1}]
    recipes = [{"name": "eggs", "nutrients": {
        "vitaminD_mcg": 15, "b12_mcg": 2.2, "iron_mg": 19,
        "calcium_mg": 1000, "magnesium_mg": 440, "zinc_mg": 17, "folate_mcg": 300,
        "potassium_mg": 3510, "omega3_g": 2.2,
    }}]
    assert detect_gaps(diary, recipes, 21) == {}


def test_pacing_detects_missed_logging_after_lunch():
    assert detect_gaps([], [], 14) == {"missed_logging": True}
    assert expected_fraction_by_hour(6) == 0.0
    assert expected_fraction_by_hour(21) == 1.0
