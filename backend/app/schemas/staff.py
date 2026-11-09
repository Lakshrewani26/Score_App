from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.orders import OrderItemCreate


class StaffAssignedPartnerResponse(BaseModel):
    id: int
    name: str
    mobile: str
    business_name: str
    business_address: str
    partner_code: str | None = None


class StaffOrderActionRequest(BaseModel):
    remarks: Optional[str] = Field(default=None, max_length=500, description="Remarks for approval or rejection")


class StaffOrderStatusUpdateRequest(BaseModel):
    status: str = Field(
        ...,
        description="Target order status. Only 'dispatched' and 'delivered' are allowed for Staff progression.",
        examples=["dispatched", "delivered"],
    )
    remarks: Optional[str] = Field(
        default=None,
        max_length=500,
        description="Optional remarks for the status update audit trail.",
    )


class StaffOrderCreateRequest(BaseModel):
    partner_id: int = Field(..., ge=1, description="Partner/Dealer user ID for whom the order is created")
    items: list[OrderItemCreate] = Field(..., min_length=1, description="Order item list")
    notes: Optional[str] = Field(default=None, max_length=1000, description="Optional order notes")
    idempotency_key: Optional[str] = Field(
        default=None,
        max_length=128,
        description="Optional client-generated key to prevent duplicate orders on retry",
    )


class StaffDashboardStatsResponse(BaseModel):
    dealers_count: int
    pending_orders_count: int
    pending_payments_count: int


class StaffQrCodeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    qr_type: str
    token: str
    code_data: str
    status: str
    target_user_id: int
    points_awarded: Optional[int] = None
    created_at: datetime
    expires_at: Optional[datetime] = None


class StaffQrResolveRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    token: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Raw QR code token or scanned QR URL payload.",
    )
    code_data: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Scanned QR code URL or raw token payload.",
    )

    @model_validator(mode="before")
    @classmethod
    def validate_token_or_code_data(cls, data: Any) -> Any:
        if isinstance(data, dict):
            raw = data.get("token") or data.get("code_data")
            if not raw or not str(raw).strip():
                raise ValueError("Either 'token' or 'code_data' must be provided and non-empty.")
            if not data.get("token"):
                data["token"] = str(raw).strip()
        return data


class StaffQrResolveResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    staff_user_id: int
    staff_name: str
    staff_id: Optional[str] = None
    qr_code_id: int
    qr_type: str


