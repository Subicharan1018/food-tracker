import pytest
from app.config import Settings

def test_config_defaults():
    # Verify default fallback port is 8000 when no environment variable is provided
    default_settings = Settings(_env_file=None)
    assert default_settings.server_port == 8000
    assert default_settings.server_host == "0.0.0.0"
    assert default_settings.ai_timeout_seconds == 120
    assert "nemotron" in default_settings.nemotron_model

    # Verify custom dynamic port override works
    custom = Settings(_env_file=None, server_port=9050)
    assert custom.server_port == 9050

def test_production_config_validation_fails_on_dummy_key():
    s = Settings(environment="production", openrouter_api_key="sk-or-dummy-key")
    with pytest.raises(RuntimeError, match="PRODUCTION CONFIG ERROR"):
        s.validate_production_config()

def test_production_config_validation_succeeds(tmp_path):
    cred_file = tmp_path / "cred.json"
    cred_file.write_text("{}", encoding="utf-8")
    s = Settings(
        environment="production",
        openrouter_api_key="sk-or-valid-live-key",
        google_application_credentials=str(cred_file),
    )
    s.validate_production_config() # Should not raise
