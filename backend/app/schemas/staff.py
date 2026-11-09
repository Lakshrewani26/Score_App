from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, Field

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
