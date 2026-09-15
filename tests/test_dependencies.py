import pytest
from fastapi import HTTPException
from app.dependencies import (
    get_firestore_service,
    get_nemotron_service,
    get_context_builder,
    get_fcm_service,
    verify_api_key,
)
from app.config import settings

def test_dependencies_instantiation():
    assert get_firestore_service() is not None
    assert get_nemotron_service() is not None
    assert get_context_builder() is not None
    assert get_fcm_service() is not None

@pytest.mark.asyncio
async def test_verify_api_key(monkeypatch):
    monkeypatch.setattr(settings, "server_api_key", "test-secret-key")
    
    # Valid key
    assert await verify_api_key("test-secret-key") is True
    
    # Invalid key
    with pytest.raises(HTTPException) as exc:
        await verify_api_key("wrong-key")
    assert exc.value.status_code == 401
