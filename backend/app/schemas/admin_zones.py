from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ZoneCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100, description="Unique zone name")
    description: Optional[str] = Field(None, description="Optional zone description")
    is_active: bool = Field(True, description="Whether zone is initially active")

    @field_validator("name", mode="before")
    @classmethod
    def validate_name(cls, v: Any) -> Any:
        if isinstance(v, str):
            stripped = v.strip()
            if not stripped:
                raise ValueError("Zone name cannot be empty or whitespace only.")
            return stripped
        return v

    @field_validator("description", mode="before")
    @classmethod
    def clean_description(cls, v: Any) -> Any:
        if isinstance(v, str):
            stripped = v.strip()
            return stripped if stripped else None
        return v


class ZoneUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = None
    is_active: Optional[bool] = None

    @field_validator("name", mode="before")
    @classmethod
    def validate_name(cls, v: Any) -> Any:
        if isinstance(v, str):
            stripped = v.strip()
            if not stripped:
                raise ValueError("Zone name cannot be empty or whitespace only.")
            return stripped
        return v

    @field_validator("description", mode="before")
    @classmethod
    def clean_description(cls, v: Any) -> Any:
        if isinstance(v, str):
            stripped = v.strip()
            return stripped if stripped else None
        return v


class ZoneStatusUpdate(BaseModel):
    is_active: bool = Field(..., description="Target active status for the zone")


class ZoneResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    partner_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class ZoneListResponse(BaseModel):
    items: list[ZoneResponse]
    total: int
