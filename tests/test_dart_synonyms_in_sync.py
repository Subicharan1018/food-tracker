from app.scripts.export_synonyms_dart import DART_PATH, render


def test_generated_dart_synonyms_match_python_table():
    """The app canonicalizes cart/pantry names offline; it must agree with the backend."""
    assert DART_PATH.read_text(encoding="utf-8") == render(), (
        "Run `python -m app.scripts.export_synonyms_dart` after editing ingredient_synonyms.py"
    )
