from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import Literal, Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


VALID_CATEGORIES = (
    "customer_qr_scan",
    "partner_qr_scan",
    "product_qr_scan",
    "invoice_qr_scan",
    "redemption",
    "customer_to_partner_transfer",
    "partner_to_staff_transfer",
)

PointsRuleCategory = Literal[
    "customer_qr_scan",
    "partner_qr_scan",
    "product_qr_scan",
    "invoice_qr_scan",
    "redemption",
    "customer_to_partner_transfer",
    "partner_to_staff_transfer",
]


def _normalize_dt(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


class SystemInfoResponse(BaseModel):
    app_name: str
    environment: str
    api_version: str
    database_status: str

    model_config = ConfigDict(from_attributes=True)


class PointsRuleCreate(BaseModel):
    rule_name: str = Field(..., min_length=1, max_length=120)
    rule_description: str | None = Field(default=None, max_length=2000)
    category: PointsRuleCategory
    points_awarded: int | None = Field(default=None, ge=0)
    points_required: int | None = Field(default=None, ge=0)
    conversion_rate: Decimal | None = Field(default=None, ge=0)
    point_value: Decimal | None = Field(default=None, ge=0)
    min_transaction_value: Decimal | None = Field(default=None, ge=0)
    max_transaction_value: Decimal | None = Field(default=None, ge=0)
    effective_from: datetime | None = None
    effective_to: datetime | None = None
    is_active: bool = True

    model_config = ConfigDict(extra="forbid")

    @field_validator("rule_name")
    @classmethod
    def validate_rule_name(cls, v: str) -> str:
        clean = v.strip()
        if not clean:
            raise ValueError("Rule name cannot be empty or whitespace only")
        return clean

    @model_validator(mode="after")
    def validate_cross_field_rules(self) -> Self:
        if (
            self.min_transaction_value is not None
            and self.max_transaction_value is not None
            and self.min_transaction_value > self.max_transaction_value
        ):
            raise ValueError("Minimum transaction value cannot exceed maximum transaction value")

        start_norm = _normalize_dt(self.effective_from)
        end_norm = _normalize_dt(self.effective_to)
        if start_norm is not None and end_norm is not None and start_norm > end_norm:
            raise ValueError("Effective start date cannot be after effective end date")

        return self


class PointsRuleUpdate(BaseModel):
    rule_name: str | None = Field(default=None, min_length=1, max_length=120)
    rule_description: str | None = Field(default=None, max_length=2000)
    category: PointsRuleCategory | None = None
    points_awarded: int | None = Field(default=None, ge=0)
    points_required: int | None = Field(default=None, ge=0)
    conversion_rate: Decimal | None = Field(default=None, ge=0)
    point_value: Decimal | None = Field(default=None, ge=0)
    min_transaction_value: Decimal | None = Field(default=None, ge=0)
    max_transaction_value: Decimal | None = Field(default=None, ge=0)
    effective_from: datetime | None = None
    effective_to: datetime | None = None
    is_active: bool | None = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("rule_name")
    @classmethod
    def validate_rule_name(cls, v: str | None) -> str | None:
        if v is not None:
            clean = v.strip()
            if not clean:
                raise ValueError("Rule name cannot be empty or whitespace only")
            return clean
        return v

    @model_validator(mode="after")
    def validate_cross_field_rules(self) -> Self:
        if (
            self.min_transaction_value is not None
            and self.max_transaction_value is not None
            and self.min_transaction_value > self.max_transaction_value
        ):
            raise ValueError("Minimum transaction value cannot exceed maximum transaction value")

        start_norm = _normalize_dt(self.effective_from)
        end_norm = _normalize_dt(self.effective_to)
        if start_norm is not None and end_norm is not None and start_norm > end_norm:
            raise ValueError("Effective start date cannot be after effective end date")

        return self


class PointsRuleStatusUpdate(BaseModel):
    is_active: bool

    model_config = ConfigDict(extra="forbid")


class PointsRuleResponse(BaseModel):
    id: int
    rule_name: str
    rule_description: str | None = None
    category: str
    points_awarded: int | None = None
    points_required: int | None = None
    conversion_rate: Decimal | None = None
    point_value: Decimal | None = None
    min_transaction_value: Decimal | None = None
    max_transaction_value: Decimal | None = None
    effective_from: datetime | None = None
    effective_to: datetime | None = None
    is_active: bool
    is_current: bool = True
    version: int = 1
    parent_rule_id: int | None = None
    effective_status: str = "currently_effective"
    is_currently_effective: bool = True
    is_future_scheduled: bool = False
    created_at: datetime
    updated_at: datetime
    created_by: int | None = None
    updated_by: int | None = None
    created_by_name: str | None = None
    updated_by_name: str | None = None

    model_config = ConfigDict(from_attributes=True)


class PointsRuleListResponse(BaseModel):
    items: list[PointsRuleResponse]
    total: int

    model_config = ConfigDict(from_attributes=True)


class PointsRuleHistoryResponse(BaseModel):
    rule_id: int
    rule_name: str
    current_version: int
    latest_version: int = 1
    effective_version: int | None = None
    history: list[PointsRuleResponse]

    model_config = ConfigDict(from_attributes=True)
