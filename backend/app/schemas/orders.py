from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class OrderItemCreate(BaseModel):
    product_id: int = Field(..., ge=1, description="Product ID to order")
    quantity: int = Field(..., ge=1, description="Quantity to order (must be positive integer)")


class OrderCreateRequest(BaseModel):
    items: list[OrderItemCreate] = Field(..., min_length=1, description="Order item list")
    notes: Optional[str] = Field(default=None, max_length=1000, description="Optional order notes")
    idempotency_key: Optional[str] = Field(
        default=None,
        max_length=128,
        description="Optional client-generated key to prevent duplicate orders on retry",
    )


class OrderItemResponse(BaseModel):
    id: int
    product_id: int
    product_code: str
    product_name: str
    vehicle_type: str
    quantity: int
    unit_price: Decimal
    subtotal: Decimal

    model_config = ConfigDict(from_attributes=True)


class OrderResponse(BaseModel):
    id: int
    order_number: str
    partner_id: int
    partner_name: str
    business_name: Optional[str] = None
    business_address: Optional[str] = None
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
    items: list[OrderItemResponse] = []

    model_config = ConfigDict(from_attributes=True)


class OrderPreviewItem(BaseModel):
    product_id: int
    product_code: str
    product_name: str
    vehicle_type: str
    quantity: int
    unit_price: Decimal
    subtotal: Decimal


class OrderPreviewResponse(BaseModel):
    items: list[OrderPreviewItem]
    item_count: int
    total_quantity: int
    grand_total: Decimal


class WhatsAppDeliveryResult(BaseModel):
    success: bool
    status: str
    message: str
    recipient: Optional[str] = None
    provider: str
    message_id: Optional[str] = None
