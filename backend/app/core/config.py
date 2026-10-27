from __future__ import annotations

from typing import Self
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Score API"
    environment: str = "development"
    database_url: str | None = None

    # JWT Authentication configuration
    jwt_secret_key: str | None = None
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 480

    # Production CORS allowed origins
    cors_allowed_origins: list[str] = []

    # WhatsApp Integration configuration
    whatsapp_provider: str = "cloud_api"
    whatsapp_api_token: str | None = None
    whatsapp_phone_number_id: str | None = None
    whatsapp_business_account_id: str | None = None
    whatsapp_admin_recipient: str | None = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @model_validator(mode="after")
    def validate_production_security(self) -> Self:
        if self.environment.lower() == "production":
            if not self.jwt_secret_key or not self.jwt_secret_key.strip():
                raise ValueError(
                    "JWT_SECRET_KEY is required in production environment."
                )
            if len(self.jwt_secret_key.strip()) < 32:
                raise ValueError(
                    "JWT_SECRET_KEY must be at least 32 characters long in production."
                )
        return self


settings = Settings()
