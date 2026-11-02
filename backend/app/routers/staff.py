from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.security import require_staff
from app.db.session import get_db
from app.models import (
    Order,
    OrderItem,
    OrderStatusHistory,
    PartnerProfile,
    StaffPartnerAssignment,
    StaffPaymentRecord,
    StaffProfile,
    User,
)
from app.routers.orders import _build_order_response
from app.schemas.auth import StaffUserResponse
from app.schemas.orders import OrderResponse
from app.schemas.staff import (
    StaffAssignedPartnerResponse,
    StaffDashboardStatsResponse,
    StaffOrderActionRequest,
)

router = APIRouter(prefix="/api/v1/staff", tags=["staff"])


@router.get("/me", response_model=StaffUserResponse)
def get_current_staff(
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> StaffUserResponse:
    profile = db.scalar(
        select(StaffProfile).where(StaffProfile.user_id == current_staff.id)
    )
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff profile not found",
        )
    return StaffUserResponse(
        id=current_staff.id,
        name=current_staff.name,
        mobile=current_staff.mobile,
        role=current_staff.role,
        is_active=current_staff.is_active,
        staff_id=profile.staff_id,
        created_at=current_staff.created_at,
    )


@router.get("/dashboard", response_model=StaffDashboardStatsResponse)
def get_staff_dashboard_stats(
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> StaffDashboardStatsResponse:
    """
    Returns live numeric dashboard statistics for the authenticated staff member:
    - dealers_count: number of active assigned partners.
    - pending_orders_count: count of pending_approval orders placed by assigned partners.
    - pending_payments_count: count of recorded payment records associated with this staff.
    """
    dealers_count = db.scalar(
        select(func.count(StaffPartnerAssignment.id)).where(
            StaffPartnerAssignment.staff_id == current_staff.id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    ) or 0

    pending_orders_count = db.scalar(
        select(func.count(Order.id))
        .join(
            StaffPartnerAssignment,
            StaffPartnerAssignment.partner_id == Order.partner_id,
        )
        .where(
            StaffPartnerAssignment.staff_id == current_staff.id,
            StaffPartnerAssignment.is_active.is_(True),
            Order.status == "pending_approval",
        )
    ) or 0

    pending_payments_count = db.scalar(
        select(func.count(StaffPaymentRecord.id)).where(
            StaffPaymentRecord.staff_id == current_staff.id,
            StaffPaymentRecord.status == "recorded",
        )
    ) or 0

    return StaffDashboardStatsResponse(
        dealers_count=dealers_count,
        pending_orders_count=pending_orders_count,
        pending_payments_count=pending_payments_count,
    )


@router.get("/partners", response_model=list[StaffAssignedPartnerResponse])
def list_assigned_partners(
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> list[StaffAssignedPartnerResponse]:
    partners = db.scalars(
        select(PartnerProfile)
        .join(
            StaffPartnerAssignment,
            StaffPartnerAssignment.partner_id == PartnerProfile.user_id,
        )
        .join(User, User.id == PartnerProfile.user_id)
        .options(selectinload(PartnerProfile.user))
        .where(
            StaffPartnerAssignment.staff_id == current_staff.id,
            StaffPartnerAssignment.is_active.is_(True),
            User.is_active.is_(True),
            User.role == "partner",
        )
        .order_by(PartnerProfile.business_name, PartnerProfile.user_id)
    ).all()
    return [
        StaffAssignedPartnerResponse(
            id=profile.user.id,
            name=profile.user.name,
            mobile=profile.user.mobile,
            business_name=profile.business_name,
            business_address=profile.business_address,
            partner_code=profile.partner_code,
        )
        for profile in partners
    ]


@router.get("/orders", response_model=list[OrderResponse])
def list_staff_orders(
    status: Optional[str] = Query(default=None, description="Filter by order status"),
    search: Optional[str] = Query(default=None, description="Search by order number or partner info"),
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> list[OrderResponse]:
    """
    Returns orders placed by partners actively assigned to the authenticated staff member.
    Does not expose orders from partners assigned to other staff or unassigned orders.
    """
    assigned_partner_ids_subq = (
        select(StaffPartnerAssignment.partner_id)
        .where(
            StaffPartnerAssignment.staff_id == current_staff.id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    )

    query = (
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
        )
        .where(Order.partner_id.in_(assigned_partner_ids_subq))
    )

    if status:
        query = query.where(Order.status == status)

    if search:
        clean_search = search.strip()
        if clean_search:
            pattern = f"%{clean_search}%"
            query = query.where(
                Order.order_number.ilike(pattern)
                | Order.partner.has(User.name.ilike(pattern))
                | Order.partner.has(User.mobile.ilike(pattern))
                | Order.partner.has(
                    User.partner_profile.has(PartnerProfile.business_name.ilike(pattern))
                )
            )

    query = query.order_by(Order.created_at.desc(), Order.id.desc())
    orders = db.scalars(query).all()
    return [_build_order_response(o) for o in orders]


@router.get("/orders/{order_id}", response_model=OrderResponse)
def get_staff_order_detail(
    order_id: int,
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> OrderResponse:
    """
    Returns single order detail for an order belonging to an assigned partner.
    """
    order = db.scalars(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
        )
        .where(Order.id == order_id)
    ).first()

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )

    is_assigned = db.scalar(
        select(func.count(StaffPartnerAssignment.id)).where(
            StaffPartnerAssignment.staff_id == current_staff.id,
            StaffPartnerAssignment.partner_id == order.partner_id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    )
    if not is_assigned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You are not assigned to this partner's account.",
        )

    return _build_order_response(order)


@router.post("/orders/{order_id}/approve", response_model=OrderResponse)
def approve_order(
    order_id: int,
    payload: Optional[StaffOrderActionRequest] = None,
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> OrderResponse:
    """
    Approves a partner order in 'pending_approval' status:
    - Verifies staff assignment to partner.
    - Transitions status to 'approved_processing'.
    - Records approver and approval timestamp.
    - Appends an audit entry in OrderStatusHistory.
    """
    order = db.scalars(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
        )
        .where(Order.id == order_id)
        .with_for_update()
    ).first()

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )

    is_assigned = db.scalar(
        select(func.count(StaffPartnerAssignment.id)).where(
            StaffPartnerAssignment.staff_id == current_staff.id,
            StaffPartnerAssignment.partner_id == order.partner_id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    )
    if not is_assigned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You are not assigned to this partner's account.",
        )

    if order.status != "pending_approval":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Order in '{order.status}' status cannot be approved. Only orders pending approval may be approved.",
        )

    order.status = "approved_processing"
    order.approved_by = current_staff.id
    order.approved_at = datetime.now(timezone.utc)

    remarks = payload.remarks.strip() if (payload and payload.remarks and payload.remarks.strip()) else "Order approved by Staff"
    history = OrderStatusHistory(
        order_id=order.id,
        old_status="pending_approval",
        new_status="approved_processing",
        changed_by=current_staff.id,
        remarks=remarks,
    )
    db.add(history)
    db.commit()

    return _build_order_response(order)


@router.post("/orders/{order_id}/reject", response_model=OrderResponse)
def reject_order(
    order_id: int,
    payload: Optional[StaffOrderActionRequest] = None,
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> OrderResponse:
    """
    Rejects a partner order in 'pending_approval' status:
    - Verifies staff assignment to partner.
    - Transitions status to 'rejected'.
    - Appends an audit entry in OrderStatusHistory.
    """
    order = db.scalars(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
        )
        .where(Order.id == order_id)
        .with_for_update()
    ).first()

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )

    is_assigned = db.scalar(
        select(func.count(StaffPartnerAssignment.id)).where(
            StaffPartnerAssignment.staff_id == current_staff.id,
            StaffPartnerAssignment.partner_id == order.partner_id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    )
    if not is_assigned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You are not assigned to this partner's account.",
        )

    if order.status != "pending_approval":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Order in '{order.status}' status cannot be rejected. Only orders pending approval may be rejected.",
        )

    order.status = "rejected"

    remarks = payload.remarks.strip() if (payload and payload.remarks and payload.remarks.strip()) else "Order rejected by Staff"
    if order.notes:
        order.notes = f"{order.notes}\n[Rejection remarks: {remarks}]"
    else:
        order.notes = f"[Rejection remarks: {remarks}]"

    history = OrderStatusHistory(
        order_id=order.id,
        old_status="pending_approval",
        new_status="rejected",
        changed_by=current_staff.id,
        remarks=remarks,
    )
    db.add(history)
    db.commit()

    return _build_order_response(order)
