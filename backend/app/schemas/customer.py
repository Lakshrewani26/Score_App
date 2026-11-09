from __future__ import annotations

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class CustomerBalanceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    points_earned: int = Field(
        ...,
        description="Total lifetime points earned by the customer (via QR scans and credits)",
    )
    points_spent: int = Field(
        ...,
        description="Total points spent/transferred by the customer",
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


class CustomerPointHistoryItem(BaseModel):
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
        description="Direction of points movement: 'credit' (earned) or 'debit' (spent)",
    )
    points: int = Field(
        ...,
        description="Signed points delta (positive for earnings/credits, negative for deductions/spent)",
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
        description="Recipient name for outbound transfers",
    )
    sender_name: Optional[str] = Field(
        default=None,
        description="Sender name for inbound transfers",
    )
    created_at: datetime = Field(
        ...,
        description="Transaction timestamp in UTC",
    )


class CustomerPointsHistoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    items: list[CustomerPointHistoryItem] = Field(
        default_factory=list,
        description="List of history transactions for current page",
    )
    total: int = Field(
        default=0,
        description="Total count of history transactions for this user",
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
