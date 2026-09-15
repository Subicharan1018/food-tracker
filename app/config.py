import logging
import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    openrouter_api_key: str = "sk-or-dummy-key"
    openrouter_base_url: str = "https://openrouter.ai/api/v1"
    nemotron_model: str = "nvidia/nemotron-3-ultra-550b-a55b:free"
    ai_timeout_seconds: int = 120
    google_application_credentials: str = "service-account.json"
    firebase_project_id: str = "food-tracker-b8a23"
    server_host: str = "0.0.0.0"
    server_port: int = 8000
    environment: str = "development"
    server_api_key: str | None = None
    recomp_manual_path: str = "assets/recomp_manual_v3.txt"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    def validate_production_config(self):
        """Ensures production environment fails fast if secrets or credentials are unconfigured."""
        if self.environment.lower() == "production":
            if not self.openrouter_api_key or "dummy" in self.openrouter_api_key:
                raise RuntimeError("PRODUCTION CONFIG ERROR: OPENROUTER_API_KEY is not configured in .env")
            if not os.path.exists(self.google_application_credentials):
                raise RuntimeError(f"PRODUCTION CONFIG ERROR: Google credentials file '{self.google_application_credentials}' not found.")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("kinetik")

settings = Settings()
