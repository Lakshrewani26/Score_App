from __future__ import annotations

from pydantic import BaseModel


class StaffAssignedPartnerResponse(BaseModel):
    id: int
    name: str
    mobile: str
    business_name: str
    business_address: str
    partner_code: str | None = None
