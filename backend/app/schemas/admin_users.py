from __future__ import annotations

from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models import CustomerProfile, PartnerProfile, StaffProfile, User


# ---------------------------------------------------------------------------
# Profile Output Schemas
# ---------------------------------------------------------------------------

class CustomerProfileOut(BaseModel):
    state: Optional[str] = None
    city: Optional[str] = None
    segment: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class PartnerProfileOut(BaseModel):
    business_name: str
    business_address: str
    partner_code: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class StaffProfileOut(BaseModel):
    staff_id: str

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# User Summary Schema (used for lists and status updates)
# ---------------------------------------------------------------------------

class AdminUserSummary(BaseModel):
    id: int
    name: str
    mobile: str
    role: str
    is_active: bool
    created_at: datetime

    # Role-specific summary identifiers where available
    business_name: Optional[str] = None
    partner_code: Optional[str] = None
    staff_id: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="before")
    @classmethod
    def extract_summary_fields(cls, data: Any) -> Any:
        if hasattr(data, "id") and hasattr(data, "role") and not isinstance(data, dict):
            partner: Optional[PartnerProfile] = getattr(data, "partner_profile", None)
            staff: Optional[StaffProfile] = getattr(data, "staff_profile", None)
            return {
                "id": data.id,
                "name": data.name,
                "mobile": data.mobile,
                "role": data.role,
                "is_active": data.is_active,
                "created_at": data.created_at,
                "business_name": partner.business_name if partner else None,
                "partner_code": partner.partner_code if partner else None,
                "staff_id": staff.staff_id if staff else None,
            }
        return data


# ---------------------------------------------------------------------------
# User Detail Schema (includes full role-specific profile data)
# ---------------------------------------------------------------------------

class AdminUserDetailResponse(AdminUserSummary):
    customer_profile: Optional[CustomerProfileOut] = None
    partner_profile: Optional[PartnerProfileOut] = None
    staff_profile: Optional[StaffProfileOut] = None

    @model_validator(mode="before")
    @classmethod
    def extract_detail_fields(cls, data: Any) -> Any:
        if hasattr(data, "id") and hasattr(data, "role") and not isinstance(data, dict):
            cust: Optional[CustomerProfile] = getattr(data, "customer_profile", None)
            partner: Optional[PartnerProfile] = getattr(data, "partner_profile", None)
            staff: Optional[StaffProfile] = getattr(data, "staff_profile", None)
            return {
                "id": data.id,
                "name": data.name,
                "mobile": data.mobile,
                "role": data.role,
                "is_active": data.is_active,
                "created_at": data.created_at,
                "business_name": partner.business_name if partner else None,
                "partner_code": partner.partner_code if partner else None,
                "staff_id": staff.staff_id if staff else None,
                "customer_profile": cust,
                "partner_profile": partner,
                "staff_profile": staff,
            }
        return data


# ---------------------------------------------------------------------------
# Pagination Schemas
# ---------------------------------------------------------------------------

class PaginationMetadata(BaseModel):
    total: int
    page: int
    page_size: int
    total_pages: int


class PaginatedUsersResponse(BaseModel):
    items: list[AdminUserSummary]
    total: int
    page: int
    page_size: int
    total_pages: int
    pagination: Optional[PaginationMetadata] = None


# ---------------------------------------------------------------------------
# Partner Creation Request
# ---------------------------------------------------------------------------

class PartnerCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=150, description="Full contact name")
    mobile: str = Field(..., min_length=1, max_length=20, description="Unique mobile number")
    password: str = Field(..., min_length=1, max_length=128, description="Initial account password")
    business_name: str = Field(..., min_length=1, max_length=200, description="Partner business name")
    business_address: str = Field(..., min_length=1, description="Physical business address")
    partner_code: Optional[str] = Field(None, max_length=50, description="Optional partner code")

    @field_validator("name", "mobile", "business_name", "business_address", mode="before")
    @classmethod
    def validate_non_empty_strings(cls, v: Any) -> Any:
        if isinstance(v, str):
            stripped = v.strip()
            if not stripped:
                raise ValueError("Field cannot be empty or whitespace only.")
            return stripped
        return v

    @field_validator("password", mode="before")
    @classmethod
    def validate_password(cls, v: Any) -> Any:
        if isinstance(v, str):
            if not v or not v.strip():
                raise ValueError("Password cannot be empty or whitespace only.")
            return v
        return v

    @field_validator("partner_code", mode="before")
    @classmethod
    def clean_partner_code(cls, v: Any) -> Any:
        if isinstance(v, str):
            stripped = v.strip()
            return stripped if stripped else None
        return v


# ---------------------------------------------------------------------------
# Staff Creation Request
# ---------------------------------------------------------------------------

class StaffCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=150, description="Full staff name")
    mobile: str = Field(..., min_length=1, max_length=20, description="Unique mobile number")
    password: str = Field(..., min_length=1, max_length=128, description="Initial account password")
    staff_id: str = Field(..., min_length=1, max_length=50, description="Unique staff employee ID")

    @field_validator("name", "mobile", "staff_id", mode="before")
    @classmethod
    def validate_non_empty_strings(cls, v: Any) -> Any:
        if isinstance(v, str):
            stripped = v.strip()
            if not stripped:
                raise ValueError("Field cannot be empty or whitespace only.")
            return stripped
        return v

    @field_validator("password", mode="before")
    @classmethod
    def validate_password(cls, v: Any) -> Any:
        if isinstance(v, str):
            if not v or not v.strip():
                raise ValueError("Password cannot be empty or whitespace only.")
            return v
        return v


# ---------------------------------------------------------------------------
# Account Status Update Request
# ---------------------------------------------------------------------------

class AccountStatusUpdateRequest(BaseModel):
    is_active: bool = Field(..., description="Target active status")


class StaffPartnerAssignmentCreateRequest(BaseModel):
    staff_id: int = Field(..., gt=0)
    partner_id: int = Field(..., gt=0)


class AssignmentUserResponse(BaseModel):
    id: int
    name: str
    mobile: str
    role: str
    is_active: bool
    staff_id: Optional[str] = None
    business_name: Optional[str] = None
    partner_code: Optional[str] = None


class StaffPartnerAssignmentResponse(BaseModel):
    id: int
    staff_id: int
    partner_id: int
    assigned_at: datetime
    is_active: bool
    staff: AssignmentUserResponse
    partner: AssignmentUserResponse

    model_config = ConfigDict(from_attributes=True)
