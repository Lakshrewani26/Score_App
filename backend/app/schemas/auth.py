from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


class AdminLoginRequest(BaseModel):
    mobile: str = Field(..., min_length=1, max_length=20, description="Mobile number")
    password: str = Field(..., min_length=1, description="Admin password")


class AdminUserResponse(BaseModel):
    id: int
    name: str
    mobile: str
    role: str
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: AdminUserResponse


class AdminPasswordUpdateRequest(BaseModel):
    current_password: str = Field(
        ..., min_length=1, description="Current Admin password"
    )
    new_password: str = Field(
        ...,
        min_length=8,
        max_length=128,
        description="New Admin password (minimum 8 characters)",
    )

    @field_validator("current_password", mode="before")
    @classmethod
    def validate_current_password(cls, v: Any) -> Any:
        if isinstance(v, str):
            if not v or not v.strip():
                raise ValueError("Current password cannot be empty or whitespace only.")
            return v
        return v

    @field_validator("new_password", mode="before")
    @classmethod
    def validate_new_password(cls, v: Any) -> Any:
        if isinstance(v, str):
            if not v or not v.strip():
                raise ValueError("New password cannot be empty or whitespace only.")
            return v
        return v


class AdminPasswordUpdateResponse(BaseModel):
    message: str = "Password updated successfully"


class PartnerLoginRequest(BaseModel):
    mobile: str = Field(..., min_length=1, max_length=20, description="Partner mobile number")
    password: str = Field(..., min_length=1, description="Partner password")


class PartnerProfileData(BaseModel):
    business_name: str
    business_address: str
    partner_code: str | None = None

    model_config = ConfigDict(from_attributes=True)


class PartnerUserResponse(BaseModel):
    id: int
    name: str
    mobile: str
    role: str
    is_active: bool
    created_at: datetime
    partner_profile: PartnerProfileData | None = None

    model_config = ConfigDict(from_attributes=True)


class PartnerTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: PartnerUserResponse


class StaffLoginRequest(BaseModel):
    staff_id: str = Field(..., min_length=1, max_length=50, description="Staff ID")
    password: str = Field(..., min_length=1, description="Staff password")


class StaffUserResponse(BaseModel):
    id: int
    name: str
    mobile: str
    role: str
    is_active: bool
    staff_id: str
    created_at: datetime


class StaffTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: StaffUserResponse

