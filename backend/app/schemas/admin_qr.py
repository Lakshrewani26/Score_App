from __future__ import annotations

from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator


SupportedQrType = Literal["product", "invoice", "staff", "partner"]
SupportedBatchStatus = Literal["active", "completed", "cancelled"]
SupportedCodeStatus = Literal["active", "redeemed", "voided", "expired"]


class QrBatchCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    qr_type: SupportedQrType
    quantity: int = Field(..., ge=1, le=1000, description="Quantity of QR codes to generate (1-1000)")
    description: Optional[str] = Field(default=None, max_length=500)
    points_rule_id: Optional[int] = Field(default=None, description="Optional points rule to bind for rewards")
    product_id: Optional[int] = Field(default=None, description="Target product for product QR codes")
    target_user_id: Optional[int] = Field(default=None, description="Target partner or staff for affiliated QR codes")
    metadata: Optional[dict[str, Any]] = Field(default=None, description="Optional extra metadata")

    @model_validator(mode="after")
    def validate_category_targets(self) -> QrBatchCreate:
        if self.qr_type == "product" and not self.product_id:
            raise ValueError("product_id is required for product QR code batches")
        return self


class QrCodeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    batch_id: int
    qr_type: str
    token: str
    code_data: str
    points_awarded: Optional[int] = None
    product_id: Optional[int] = None
    product_name: Optional[str] = None
    target_user_id: Optional[int] = None
    target_user_name: Optional[str] = None
    status: str
    redeemed_by: Optional[int] = None
    redeemed_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    created_at: datetime


class QrBatchResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    batch_number: str
    qr_type: str
    description: Optional[str] = None
    points_rule_id: Optional[int] = None
    points_rule_name: Optional[str] = None
    product_id: Optional[int] = None
    product_name: Optional[str] = None
    target_user_id: Optional[int] = None
    target_user_name: Optional[str] = None
    quantity: int
    status: str
    active_count: int = 0
    redeemed_count: int = 0
    voided_count: int = 0
    created_by: Optional[int] = None
    created_by_name: Optional[str] = None
    created_at: datetime


class QrBatchListResponse(BaseModel):
    items: list[QrBatchResponse]
    total: int


class QrCodeListResponse(BaseModel):
    items: list[QrCodeResponse]
    total: int


class QrCodeStatusUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: Literal["active", "voided"]


class ProductQrLabelRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    product_ids: list[int] = Field(..., min_length=1, max_length=500, description="List of product IDs to print labels for")


class ProductQrLabelItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    product_id: int
    product_name: str
    product_code: str
    qr_number: str


class ProductQrLabelListResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    items: list[ProductQrLabelItem]
    total: int

