from __future__ import annotations

from pydantic import BaseModel


class StaffAssignedPartnerResponse(BaseModel):
    id: int
    name: str
    mobile: str
    business_name: str
    business_address: str
    partner_code: str | None = None

from typing import Optional
from pydantic import Field


class StaffOrderActionRequest(BaseModel):
    remarks: Optional[str] = Field(default=None, max_length=500, description="Remarks for approval or rejection")


class StaffDashboardStatsResponse(BaseModel):
    dealers_count: int
    pending_orders_count: int
    pending_payments_count: int
