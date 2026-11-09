from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.security import require_customer
from app.db.session import get_db
from app.models import User
from app.schemas.customer import (
    CustomerBalanceResponse,
    CustomerPointsHistoryResponse,
)
from app.services.points_service import (
    get_customer_points_history,
    get_user_points_balance,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/customer", tags=["customer"])


@router.get(
    "/balance",
    response_model=CustomerBalanceResponse,
    status_code=status.HTTP_200_OK,
    summary="Get customer points balance",
)
@router.get(
    "/points/balance",
    response_model=CustomerBalanceResponse,
    status_code=status.HTTP_200_OK,
    include_in_schema=False,
)
def get_customer_balance(
    current_customer: User = Depends(require_customer),
    db: Session = Depends(get_db),
) -> CustomerBalanceResponse:
    """
    Returns the unified points balance for the authenticated customer:
    - total earned points (direct product QR scans + verified legacy redemptions)
    - total spent points (outbound transfers to partners / ledger deductions)
    - current balance (earned - spent)

    Strictly isolated: a Customer can only retrieve their own balance.
    """
    summary = get_user_points_balance(
        db, current_customer.id, role=current_customer.role
    )

    return CustomerBalanceResponse(
        points_earned=summary.points_earned,
        points_spent=summary.points_spent,
        current_balance=summary.current_balance,
        total_earned_points=summary.points_earned,
        total_spent_points=summary.points_spent,
        remaining_balance=summary.current_balance,
    )


@router.get(
    "/points-history",
    response_model=CustomerPointsHistoryResponse,
    status_code=status.HTTP_200_OK,
    summary="Get customer paginated points history",
)
@router.get(
    "/history",
    response_model=CustomerPointsHistoryResponse,
    status_code=status.HTTP_200_OK,
    include_in_schema=False,
)
def get_customer_history(
    page: int = Query(default=1, ge=1, description="Page number (1-based)"),
    page_size: int = Query(default=20, ge=1, le=100, description="Page size (max 100)"),
    current_customer: User = Depends(require_customer),
    db: Session = Depends(get_db),
) -> CustomerPointsHistoryResponse:
    """
    Returns paginated points transaction history for the authenticated customer.
    Includes:
    - Product QR scans (PointTransaction)
    - Legacy redeemed QR codes (fallback compatibility)
    - Outbound transfer deductions to partners (PointTransfer)
    - Inbound transfers received, if applicable (PointTransfer)

    Guarantees:
    - Strict customer data isolation
    - 100% mathematical consistency with /balance endpoint
    - Deterministic newest-first sort with tie-breaker
    """
    return get_customer_points_history(
        db,
        user_id=current_customer.id,
        page=page,
        page_size=page_size,
    )
