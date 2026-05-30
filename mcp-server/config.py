from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    supabase_url: str
    supabase_service_role_key: str
    supabase_anon_key: str
    worker_base_url: str | None = None
    worker_shared_secret: str | None = None
    mcp_public_url: str = "http://localhost:8001"
    host: str = "0.0.0.0"
    port: int = 8001
    agent_daily_run_limit: int = 50
    cron_scheduler_enabled: bool = True

    model_config = SettingsConfigDict(
        env_file=("../server.env", ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
