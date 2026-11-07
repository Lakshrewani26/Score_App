from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class PaginationMetadata(BaseModel):
    total: int
    page: int
    page_size: int
    total_pages: int


# ---------------------------------------------------------------------------
# Order Schemas
# ---------------------------------------------------------------------------

class AdminOrderItemDetail(BaseModel):
    id: int
    product_id: int
    product_code: str
    product_name: str
    vehicle_type: str
    quantity: int
    unit_price: Decimal
    subtotal: Decimal
    original_price: Optional[Decimal] = None
    discount_percentage: Optional[Decimal] = None
    discount_amount: Optional[Decimal] = None
    discounted_price: Optional[Decimal] = None

    model_config = ConfigDict(from_attributes=True)


class AdminOrderStatusHistoryItem(BaseModel):
    id: int
    old_status: Optional[str] = None
    new_status: str
    changed_by: Optional[int] = None
    changed_by_name: Optional[str] = None
    changed_at: datetime
    remarks: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class AdminOrderSummary(BaseModel):
    id: int
    order_number: str
    partner_id: int
    partner_name: str
    business_name: Optional[str] = None
    partner_mobile: str
    status: str
    notes: Optional[str] = None
    created_at: datetime
    approved_by: Optional[int] = None
    approved_by_name: Optional[str] = None
    approved_at: Optional[datetime] = None
    item_count: int
    total_quantity: int
    order_total: Decimal
    subtotal_before_discount: Optional[Decimal] = None
    discount_percentage: Optional[Decimal] = None
    total_discount: Optional[Decimal] = None
    final_total: Optional[Decimal] = None

    model_config = ConfigDict(from_attributes=True)


class AdminOrderDetail(AdminOrderSummary):
    items: list[AdminOrderItemDetail]
    status_history: list[AdminOrderStatusHistoryItem]


class PaginatedOrdersResponse(BaseModel):
    items: list[AdminOrderSummary]
    total: int
    page: int
    page_size: int
    total_pages: int
    pagination: Optional[PaginationMetadata] = None


class AdminOrderStatusUpdateRequest(BaseModel):
    status: Literal["dispatched", "delivered"] = Field(
        ...,
        description="Target order status. Only 'dispatched' and 'delivered' are allowed for Admin progression.",
    )
    remarks: Optional[str] = Field(
        None,
        max_length=500,
        description="Optional remarks for the status change audit history.",
    )


# ---------------------------------------------------------------------------
# Stock Request Schemas
# ---------------------------------------------------------------------------

class AdminStockRequestItemDetail(BaseModel):
    id: int
    product_id: int
    product_code: str
    product_name: str
    vehicle_type: str
    quantity: int

    model_config = ConfigDict(from_attributes=True)


class AdminStockRequestStatusHistoryItem(BaseModel):
    id: int
    old_status: Optional[str] = None
    new_status: str
    changed_by: Optional[int] = None
    changed_by_name: Optional[str] = None
    changed_at: datetime
    remarks: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class AdminStockRequestSummary(BaseModel):
    id: int
    request_number: str
    partner_id: int
    partner_name: str
    business_name: Optional[str] = None
    partner_mobile: str
    status: str
    notes: Optional[str] = None
    created_at: datetime
    reviewed_by: Optional[int] = None
    reviewed_by_name: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    item_count: int
    total_quantity: int

    model_config = ConfigDict(from_attributes=True)


class AdminStockRequestDetail(AdminStockRequestSummary):
    items: list[AdminStockRequestItemDetail]
    status_history: list[AdminStockRequestStatusHistoryItem]


class PaginatedStockRequestsResponse(BaseModel):
    items: list[AdminStockRequestSummary]
    total: int
    page: int
    page_size: int
    total_pages: int
    pagination: Optional[PaginationMetadata] = None
