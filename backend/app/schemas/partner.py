from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from pydantic import BaseModel, ConfigDict, Field, model_validator


class PartnerTransferRequest(BaseModel):
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
    amount: int = Field(
        ...,
        description="Number of loyalty points to transfer (must be a positive integer).",
    )
    idempotency_key: str = Field(
        ...,
        min_length=1,
        max_length=128,
        description="Client-provided unique key for idempotency and duplicate request protection.",
    )

    @model_validator(mode="before")
    @classmethod
    def validate_request(cls, data: Any) -> Any:
        if isinstance(data, dict):
            raw = data.get("token") or data.get("code_data")
            if not raw or not str(raw).strip():
                raise ValueError("Either 'token' or 'code_data' must be provided and non-empty.")
            if not data.get("token"):
                data["token"] = str(raw).strip()
            key = data.get("idempotency_key")
            if key is not None:
                cleaned_key = str(key).strip()
                if not cleaned_key:
                    raise ValueError("'idempotency_key' must not be blank.")
                data["idempotency_key"] = cleaned_key
        return data


class PartnerTransferResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    transfer_id: int
    amount: int
    sender_id: int
    recipient_id: int
    recipient_name: Optional[str] = None
    recipient_staff_id: Optional[str] = None
    created_at: datetime
    sender_balance: int
    recipient_balance: int
    is_idempotent_replay: bool = False


class PartnerPointHistoryItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str = Field(
        ...,
        description="Deterministic unique transaction identifier (e.g. 'pt-10', 'tr-2', 'qc-5')",
    )
    transaction_type: str = Field(
        ...,
        description="Type of transaction: 'qr_scan', 'transfer_sent', 'transfer_received', or 'legacy_qr_scan'",
    )
    direction: str = Field(
        ...,
        description="Direction of points movement: 'credit' (earned) or 'debit' (spent/transferred)",
    )
    points: int = Field(
        ...,
        description="Signed points delta (positive for earnings/credits, negative for deductions/transfers)",
    )
    amount: int = Field(
        ...,
        description="Absolute integer value of points involved in transaction",
    )
    title: str = Field(
        ...,
        description="Human-readable title for the transaction",
    )
    description: Optional[str] = Field(
        default=None,
        description="Contextual details or description",
    )
    reference_id: Optional[str] = Field(
        default=None,
        description="Reference identifier such as QR token or transfer idempotency key",
    )
    recipient_name: Optional[str] = Field(
        default=None,
        description="Recipient staff/partner name for outbound transfers",
    )
    recipient_staff_id: Optional[str] = Field(
        default=None,
        description="Recipient staff ID badge for outbound transfers",
    )
    sender_name: Optional[str] = Field(
        default=None,
        description="Sender name for inbound transfers",
    )
    created_at: datetime = Field(
        ...,
        description="Transaction timestamp in UTC",
    )


class PartnerPointsHistoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    items: list[PartnerPointHistoryItem] = Field(
        default_factory=list,
        description="List of history transactions for current page",
    )
    total: int = Field(
        default=0,
        description="Total count of history transactions for this partner",
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

