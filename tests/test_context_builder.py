from app.services.context_builder import ContextBuilder

def test_context_builder_build(mock_firestore_service):
    cb = ContextBuilder(manual_text="Pre-loaded Manual Content", firestore_svc=mock_firestore_service)
    ctx = cb.build(
        user_id="user123",
        include_diary=True,
        include_workouts=True,
        include_weigh_ins=True,
        include_sleep=True,
    )

    assert "Pre-loaded Manual Content" in ctx
    assert "user123" in ctx
    assert "RECIPE DATABASE" in ctx
    assert "DIARY HISTORY" in ctx
    assert "WORKOUT SET LOGS" in ctx
    assert "WEIGH-INS" in ctx
    assert "SLEEP LOGS" in ctx

def test_context_builder_empty_records(mock_firestore_service):
    cb = ContextBuilder(manual_text="Header", firestore_svc=mock_firestore_service)
    # Test _to_csv with empty list
    csv_text = cb._to_csv([])
    assert csv_text == "(no records)"

    # Test _recipes_csv with empty list
    rec_csv = cb._recipes_csv([])
    assert rec_csv == "name,mealSlot,calories,proteinG,carbsG,fatG"
