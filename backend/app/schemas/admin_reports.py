from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class ReportDateFilter(BaseModel):
    preset: Optional[str] = None
    date_from: Optional[datetime] = None
    date_to: Optional[datetime] = None
    interval: str = "daily"

    model_config = ConfigDict(from_attributes=True)


class ReportOverview(BaseModel):
    total_orders: int = 0
    orders_pending_approval: int = 0
    orders_processing: int = 0
    orders_dispatched: int = 0
    orders_delivered: int = 0
    orders_rejected: int = 0
    total_stock_requests: int = 0
    stock_requests_pending_approval: int = 0
    stock_requests_approved: int = 0
    stock_requests_rejected: int = 0
    total_order_value: Decimal = Field(default_factory=lambda: Decimal("0.00"))

    model_config = ConfigDict(from_attributes=True)


class CatalogueSummary(BaseModel):
    total_products: int = 0
    active_products: int = 0
    inactive_products: int = 0
    total_categories: int = 0
    active_categories: int = 0
    inactive_categories: int = 0
    products_with_null_price: int = 0

    model_config = ConfigDict(from_attributes=True)


class StatusCount(BaseModel):
    status: str
    label: str
    count: int = 0

    model_config = ConfigDict(from_attributes=True)


class OrderTrendPoint(BaseModel):
    period: str
    label: str
    count: int = 0
    total_value: Decimal = Field(default_factory=lambda: Decimal("0.00"))

    model_config = ConfigDict(from_attributes=True)


class AdminReportOverviewResponse(BaseModel):
    generated_at: datetime
    filter: ReportDateFilter
    overview: ReportOverview
    catalogue_summary: CatalogueSummary
    order_status_distribution: list[StatusCount]
    stock_request_status_distribution: list[StatusCount]
    order_trends: list[OrderTrendPoint]
    unsupported_metrics: list[str] = Field(
        default_factory=lambda: [
            "points_balances_and_history",
            "qr_scans_and_batches",
            "payment_gateway_transactions",
            "inventory_stock_quantities",
        ]
    )

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Detailed Reports: Zone-wise, Area-wise, Staff-wise, Partner-wise
# ---------------------------------------------------------------------------

class ZoneWiseReportItem(BaseModel):
    zone_id: Optional[int] = None
    zone_name: str
    partner_count: int = 0
    order_count: int = 0
    total_order_value: Decimal = Field(default_factory=lambda: Decimal("0.00"))
    payment_count: int = 0
    total_payments_collected: Decimal = Field(default_factory=lambda: Decimal("0.00"))

    model_config = ConfigDict(from_attributes=True)


class ZoneWiseReportResponse(BaseModel):
    items: list[ZoneWiseReportItem]
    total_zones: int
    total_orders: int
    total_order_value: Decimal


class AreaWiseReportItem(BaseModel):
    area_name: str
    partner_count: int = 0
    order_count: int = 0
    total_order_value: Decimal = Field(default_factory=lambda: Decimal("0.00"))

    model_config = ConfigDict(from_attributes=True)


class AreaWiseReportResponse(BaseModel):
    items: list[AreaWiseReportItem]
    total_areas: int


class StaffWiseReportItem(BaseModel):
    staff_user_id: int
    staff_id: str
    name: str
    mobile: str
    assigned_partner_count: int = 0
    order_count: int = 0
    total_order_value: Decimal = Field(default_factory=lambda: Decimal("0.00"))
    payment_count: int = 0
    total_payments_collected: Decimal = Field(default_factory=lambda: Decimal("0.00"))

    model_config = ConfigDict(from_attributes=True)


class StaffWiseReportResponse(BaseModel):
    items: list[StaffWiseReportItem]
    total_staff: int


class PartnerWiseReportItem(BaseModel):
    partner_user_id: int
    partner_name: str
    business_name: str
    mobile: str
    partner_code: Optional[str] = None
    zone_name: Optional[str] = None
    order_count: int = 0
    total_order_value: Decimal = Field(default_factory=lambda: Decimal("0.00"))
    payment_count: int = 0
    total_payments_made: Decimal = Field(default_factory=lambda: Decimal("0.00"))

    model_config = ConfigDict(from_attributes=True)


class PartnerWiseReportResponse(BaseModel):
    items: list[PartnerWiseReportItem]
    total_partners: int
