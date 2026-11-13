from __future__ import annotations

from datetime import datetime
from decimal import Decimal
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


class StaffBalanceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    points_earned: int = Field(
        ...,
        description="Total lifetime points received by the staff member via transfers",
    )
    points_spent: int = Field(
        ...,
        description="Total points spent/transferred by the staff member (currently 0)",
    )
    current_balance: int = Field(
        ...,
        description="Current available points balance (earned - spent)",
    )

    # Aliases for compatibility
    total_earned_points: int = Field(
        ...,
        description="Compatibility alias for points_earned",
    )
    total_spent_points: int = Field(
        ...,
        description="Compatibility alias for points_spent",
    )
    remaining_balance: int = Field(
        ...,
        description="Compatibility alias for current_balance",
    )


class StaffPointHistoryItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str = Field(
        ...,
        description="Deterministic unique transaction identifier (e.g. 'tr-2')",
    )
    transaction_type: str = Field(
        default="transfer_received",
        description="Type of transaction: 'transfer_received'",
    )
    direction: str = Field(
        default="credit",
        description="Direction of points movement: 'credit'",
    )
    points: int = Field(
        ...,
        description="Signed points delta (positive for received transfers)",
    )
    amount: int = Field(
        ...,
        description="Absolute integer value of points transferred",
    )
    title: str = Field(
        ...,
        description="Human-readable title for the transaction",
    )
    description: Optional[str] = Field(
        default=None,
        description="Contextual details or remarks",
    )
    reference_id: Optional[str] = Field(
        default=None,
        description="Reference identifier such as transfer idempotency key",
    )
    sender_name: Optional[str] = Field(
        default=None,
        description="Sender Partner or Business name",
    )
    created_at: datetime = Field(
        ...,
        description="Transaction timestamp in UTC",
    )


class StaffPointsHistoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    items: list[StaffPointHistoryItem] = Field(
        default_factory=list,
        description="List of history transactions for current page",
    )
    total: int = Field(
        default=0,
        description="Total count of history transactions for this staff member",
    )
    page: int = Field(
        default=1,
        description="Current 1-based page number",
    )
    page_size: int = Field(
        default=20,
        description="Page size limit",
    )
    total_pages: int = Field(
        default=0,
        description="Total number of pages",
    )
    has_next: bool = Field(
        default=False,
        description="Whether a subsequent page exists",
    )
    has_prev: bool = Field(
        default=False,
        description="Whether a preceding page exists",
    )


class PaymentReviewDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    changed_by: Optional[int] = Field(default=None, description="Reviewer user ID")
    changed_by_name: Optional[str] = Field(default=None, description="Reviewer name")
    changed_at: datetime = Field(..., description="Review timestamp in UTC")
    old_status: Optional[str] = Field(default=None, description="Status prior to review")
    new_status: str = Field(..., description="Status resulting from review")
    remarks: Optional[str] = Field(default=None, description="Reviewer remarks or rejection reason")


class StaffPaymentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int = Field(..., description="Payment record ID")
    staff_id: int = Field(..., description="Assigned staff member user ID")
    partner_id: int = Field(..., description="Partner/dealer user ID")
    partner_name: Optional[str] = Field(default=None, description="Partner contact person name")
    business_name: Optional[str] = Field(default=None, description="Partner dealership/business name")
    partner_mobile: Optional[str] = Field(default=None, description="Partner mobile number")
    amount: Decimal = Field(..., description="Payment amount")
    payment_method: str = Field(..., description="Method used (cash, cheque, bank_transfer, etc.)")
    reference_number: Optional[str] = Field(default=None, description="Invoice or payment transaction reference")
    status: str = Field(..., description="Current status: recorded, approved, rejected, voided")
    recorded_by: int = Field(..., description="User ID who recorded the payment")
    recorded_by_name: Optional[str] = Field(default=None, description="Name of user who recorded the payment")
    recorded_at: datetime = Field(..., description="Recorded timestamp in UTC")
    notes: Optional[str] = Field(default=None, description="Notes entered when payment was recorded")
    latest_review: Optional[PaymentReviewDetail] = Field(default=None, description="Details of most recent review")
    status_history: list[PaymentReviewDetail] = Field(default_factory=list, description="Full audit history")


class StaffPaymentListResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    items: list[StaffPaymentResponse] = Field(
        default_factory=list,
        description="Payment records assigned to authenticated staff",
    )
    total: int = Field(default=0, description="Total matching payments count")
    page: int = Field(default=1, description="Current page number (1-based)")
    page_size: int = Field(default=20, description="Items per page")
    total_pages: int = Field(default=0, description="Total number of pages")
    has_next: bool = Field(default=False, description="Whether a subsequent page exists")
    has_prev: bool = Field(default=False, description="Whether a preceding page exists")


class StaffPaymentApproveRequest(BaseModel):
    remarks: Optional[str] = Field(
        default=None,
        max_length=500,
        description="Optional remarks for payment approval",
    )


class StaffPaymentRejectRequest(BaseModel):
    reason: Optional[str] = Field(
        default=None,
        max_length=500,
        description="Mandatory rejection reason",
    )
    remarks: Optional[str] = Field(
        default=None,
        max_length=500,
        description="Alternative field for rejection reason",
    )

    @model_validator(mode="after")
    def validate_reason_present(self) -> StaffPaymentRejectRequest:
        effective = (self.reason or self.remarks or "").strip()
        if not effective:
            raise ValueError("Rejection reason is required")
        self.reason = effective
        return self
