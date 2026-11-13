from __future__ import annotations

from datetime import datetime, timezone
import logging
from typing import Optional
from urllib.parse import parse_qs, urlparse

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.security import require_partner, require_staff, require_staff_or_admin
from app.db.session import get_db
from app.models import (
    Order,
    OrderItem,
    OrderStatusHistory,
    PartnerProfile,
    PaymentStatusHistory,
    Product,
    QrCode,
    StaffPartnerAssignment,
    StaffPaymentRecord,
    StaffProfile,
    User,
)
from app.routers.orders import _build_order_response, _generate_order_number
from app.schemas.admin_settings import _normalize_dt
from app.schemas.auth import StaffUserResponse
from app.schemas.orders import OrderResponse
from app.schemas.staff import (
    StaffAssignedPartnerResponse,
    StaffBalanceResponse,
    StaffDashboardStatsResponse,
    StaffOrderActionRequest,
    StaffOrderCreateRequest,
    StaffOrderStatusUpdateRequest,
    StaffPaymentApproveRequest,
    StaffPaymentListResponse,
    StaffPaymentRejectRequest,
    StaffPaymentResponse,
    StaffPointsHistoryResponse,
    StaffQrCodeResponse,
    StaffQrResolveRequest,
    StaffQrResolveResponse,
)
from app.services.order_service import (
    apply_order_status_transition,
    verify_staff_partner_assignment,
)
from app.services.payment_service import (
    apply_payment_status_transition,
    build_payment_response,
    verify_staff_payment_access,
)
from app.services.points_service import (
    get_staff_points_history,
    get_user_points_balance,
)

logger = logging.getLogger(__name__)

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


@router.get(
    "/balance",
    response_model=StaffBalanceResponse,
    status_code=status.HTTP_200_OK,
    summary="Get staff points balance",
)
@router.get(
    "/points/balance",
    response_model=StaffBalanceResponse,
    status_code=status.HTTP_200_OK,
    include_in_schema=False,
)
def get_staff_balance(
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> StaffBalanceResponse:
    """
    Returns the unified points balance for the authenticated staff member:
    - points_earned: total lifetime points received via partner transfers
    - points_spent: total points spent/transferred (0 for staff)
    - current_balance: net available points balance
    """
    summary = get_user_points_balance(db, current_staff.id, role="staff")
    total_earned = summary.transfers_received
    total_spent = summary.points_spent
    balance = summary.current_balance

    return StaffBalanceResponse(
        points_earned=total_earned,
        points_spent=total_spent,
        current_balance=balance,
        total_earned_points=total_earned,
        total_spent_points=total_spent,
        remaining_balance=balance,
    )


@router.get(
    "/points-history",
    response_model=StaffPointsHistoryResponse,
    status_code=status.HTTP_200_OK,
    summary="Get staff paginated points history",
)
@router.get(
    "/history",
    response_model=StaffPointsHistoryResponse,
    status_code=status.HTTP_200_OK,
    include_in_schema=False,
)
def get_staff_history(
    page: int = Query(default=1, ge=1, description="Page number (1-based)"),
    page_size: int = Query(default=20, ge=1, le=100, description="Items per page"),
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> StaffPointsHistoryResponse:
    """
    Returns paginated points transaction history for the authenticated staff member.
    Includes:
    - Points received from Partner transfers (PointTransfer)

    Guarantees:
    - Strict user data isolation: Staff only sees their own received transfers.
    - 100% mathematical consistency with net staff points balance.
    - Deterministic newest-first sort (created_at DESC, id DESC).
    """
    return get_staff_points_history(
        db,
        user_id=current_staff.id,
        page=page,
        page_size=page_size,
    )



@router.get(
    "/qr",
    response_model=StaffQrCodeResponse,
    status_code=status.HTTP_200_OK,
    summary="Retrieve assigned Staff QR code for authenticated staff user",
)
@router.get(
    "/qr-code",
    response_model=StaffQrCodeResponse,
    status_code=status.HTTP_200_OK,
    include_in_schema=False,
)
def get_my_staff_qr(
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> StaffQrCodeResponse:
    """
    Retrieves the assigned Staff QR code for the authenticated staff user.
    Only returns the QR code assigned to the currently logged-in staff member.
    Does not permit requesting another user's QR code.
    Returns 404 if no active Staff QR code is assigned.
    """
    now = datetime.now(timezone.utc)
    qr_code = db.scalar(
        select(QrCode)
        .where(
            QrCode.target_user_id == current_staff.id,
            QrCode.qr_type == "staff",
            QrCode.status == "active",
            (QrCode.expires_at.is_(None) | (QrCode.expires_at >= now)),
        )
        .order_by(QrCode.created_at.desc(), QrCode.id.desc())
    )
    if not qr_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff QR code not found.",
        )
    return StaffQrCodeResponse.model_validate(qr_code)


def _extract_token(raw_data: str) -> str:
    cleaned = raw_data.strip()
    if "token=" in cleaned:
        try:
            parsed = urlparse(cleaned)
            params = parse_qs(parsed.query)
            if "token" in params and params["token"]:
                return params["token"][0].strip()
        except Exception:
            pass
    return cleaned


@router.post(
    "/qr/resolve",
    response_model=StaffQrResolveResponse,
    status_code=status.HTTP_200_OK,
    summary="Resolve Staff QR token to assigned Staff recipient for point transfer",
)
def resolve_staff_qr(
    payload: StaffQrResolveRequest,
    current_partner: User = Depends(require_partner),
    db: Session = Depends(get_db),
) -> StaffQrResolveResponse:
    """
    Resolves a Staff QR token/URL to the assigned Staff recipient.
    Only authenticated Partners can resolve Staff QR codes.
    Validates token presence, active status, expiration, and staff role assignment.
    Does not create any point transfer or alter any balances (read-only resolution).
    """
    raw_input = (payload.token or payload.code_data or "").strip()
    if not raw_input:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A valid QR code token must be provided.",
        )

    token = _extract_token(raw_input)
    if len(token) > 64:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff QR code token not found.",
        )

    qr_code = db.scalar(
        select(QrCode)
        .options(
            selectinload(QrCode.target_user).selectinload(User.staff_profile)
        )
        .where(
            (QrCode.token == token)
            | (QrCode.token == token.upper())
            | (QrCode.token == token.lower())
        )
    )

    if qr_code is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff QR code token not found.",
        )

    if qr_code.qr_type != "staff":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Inappropriate QR code type: '{qr_code.qr_type}' QR codes cannot be resolved as Staff recipients.",
        )

    if qr_code.status != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"This QR code is not active (status: {qr_code.status}).",
        )

    now = datetime.now(timezone.utc)
    exp = _normalize_dt(qr_code.expires_at)
    if exp and exp < now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This Staff QR code has expired.",
        )

    if qr_code.target_user_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This QR code is not assigned to any staff member.",
        )

    target_user = qr_code.target_user
    if target_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Assigned staff user not found.",
        )

    if target_user.role != "staff":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Assigned user does not hold the 'staff' role (current role: '{target_user.role}').",
        )

    if not target_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Assigned staff user account is inactive.",
        )

    staff_badge_id = (
        target_user.staff_profile.staff_id
        if target_user.staff_profile
        else None
    )

    logger.info(
        "Partner ID %s resolved Staff QR ID %s for Staff user ID %s",
        current_partner.id,
        qr_code.id,
        target_user.id,
    )

    return StaffQrResolveResponse(
        staff_user_id=target_user.id,
        staff_name=target_user.name,
        staff_id=staff_badge_id,
        qr_code_id=qr_code.id,
        qr_type=qr_code.qr_type,
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
            selectinload(Order.status_history).selectinload(OrderStatusHistory.actor),
        )
        .where(Order.id == order_id)
    ).first()

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )

    verify_staff_partner_assignment(db, current_staff.id, order.partner_id)

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
            selectinload(Order.status_history).selectinload(OrderStatusHistory.actor),
        )
        .where(Order.id == order_id)
        .with_for_update()
    ).first()

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )

    verify_staff_partner_assignment(db, current_staff.id, order.partner_id)

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
            selectinload(Order.status_history).selectinload(OrderStatusHistory.actor),
        )
        .where(Order.id == order_id)
        .with_for_update()
    ).first()

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )

    verify_staff_partner_assignment(db, current_staff.id, order.partner_id)

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


@router.patch("/orders/{order_id}/status", response_model=OrderResponse)
def update_staff_order_status(
    order_id: int,
    payload: StaffOrderStatusUpdateRequest,
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> OrderResponse:
    """
    Updates order fulfillment status for an assigned partner's order:
    - Verifies staff authentication and role via require_staff.
    - Locks order row with FOR UPDATE.
    - Verifies active Staff-Partner assignment.
    - Enforces order state machine (approved_processing -> dispatched -> delivered).
    - Persists order status update and order_status_history audit record atomically.
    - Returns refreshed order with status history.
    """
    order = db.scalars(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
            selectinload(Order.status_history).selectinload(OrderStatusHistory.actor),
        )
        .where(Order.id == order_id)
        .with_for_update()
    ).first()

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )

    verify_staff_partner_assignment(db, current_staff.id, order.partner_id)

    apply_order_status_transition(
        db=db,
        order=order,
        target_status=payload.status,
        user=current_staff,
        remarks=payload.remarks,
    )

    # Re-fetch order with refreshed relations
    updated_order = db.scalars(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
            selectinload(Order.status_history).selectinload(OrderStatusHistory.actor),
        )
        .where(Order.id == order_id)
    ).first()

    return _build_order_response(updated_order or order)


@router.post("/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_staff_order(
    payload: StaffOrderCreateRequest,
    idempotency_key_header: Optional[str] = Header(None, alias="Idempotency-Key"),
    db: Session = Depends(get_db),
    current_staff: User = Depends(require_staff),
) -> OrderResponse:
    """
    Creates an order on behalf of an assigned Partner/Dealer:
    1. Verifies that the staff member is actively assigned to the target partner.
    2. Validates product availability and server-side pricing.
    3. Persists the order against the exact Partner ID.
    4. Sets order status to 'pending_approval'.
    5. Records audit trail in order status history.
    """
    if not payload.items:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Order must contain at least one item.",
        )

    # 1. Partner exists and is active partner
    partner = db.get(User, payload.partner_id)
    if partner is None or partner.role != "partner" or not partner.is_active:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Partner not found or inactive.",
        )

    # 2. Verify staff assignment to partner
    is_assigned = db.scalar(
        select(func.count(StaffPartnerAssignment.id)).where(
            StaffPartnerAssignment.staff_id == current_staff.id,
            StaffPartnerAssignment.partner_id == payload.partner_id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    )
    if not is_assigned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You are not assigned to this partner's account.",
        )

    # 3. Idempotency Check
    raw_idempotency_key = payload.idempotency_key or idempotency_key_header
    idempotency_key = raw_idempotency_key.strip() if raw_idempotency_key else None

    if idempotency_key:
        tag = f"[idempotency_key:{idempotency_key}]"
        existing_order = db.scalars(
            select(Order)
            .options(
                selectinload(Order.partner).selectinload(User.partner_profile),
                selectinload(Order.approver),
                selectinload(Order.items).selectinload(OrderItem.product),
            )
            .where(
                Order.partner_id == payload.partner_id,
                Order.notes.contains(tag),
            )
        ).first()

        if existing_order:
            return _build_order_response(existing_order)

    # 4. Fetch products and validate prices server-side
    product_ids = [item.product_id for item in payload.items]
    products = db.scalars(select(Product).where(Product.id.in_(product_ids))).all()
    products_by_id = {p.id: p for p in products}

    order_items_to_create: list[OrderItem] = []

    for item in payload.items:
        if item.quantity <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Item quantity must be greater than zero for product ID {item.product_id}.",
            )

        product = products_by_id.get(item.product_id)
        if product is None or not product.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Product ID {item.product_id} is unavailable or not found.",
            )

        if product.price is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    f"Product '{product.name}' (Code: {product.product_code}) has no valid price. "
                    "Cannot place order until pricing is configured by Admin."
                ),
            )

        order_items_to_create.append(
            OrderItem(
                product_id=product.id,
                quantity=item.quantity,
                unit_price=product.price,
            )
        )

    # 5. Build order record
    notes_parts = []
    if payload.notes and payload.notes.strip():
        notes_parts.append(payload.notes.strip())
    notes_parts.append(f"[Created by Staff: {current_staff.name} (ID: {current_staff.id})]")
    if idempotency_key:
        notes_parts.append(f"[idempotency_key:{idempotency_key}]")
    full_notes = "\n".join(notes_parts)

    order_number = _generate_order_number(db)
    new_order = Order(
        order_number=order_number,
        partner_id=payload.partner_id,
        status="pending_approval",
        notes=full_notes,
    )
    db.add(new_order)
    db.flush()

    for item in order_items_to_create:
        item.order_id = new_order.id
        db.add(item)

    # 6. Status history record
    history_entry = OrderStatusHistory(
        order_id=new_order.id,
        old_status=None,
        new_status="pending_approval",
        changed_by=current_staff.id,
        remarks=f"Order created by Staff {current_staff.name} for Partner {partner.name}",
    )
    db.add(history_entry)

    db.commit()

    # 7. Reload with full relations
    saved_order = db.scalars(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
        )
        .where(Order.id == new_order.id)
    ).first()

    return _build_order_response(saved_order)


# =============================================================================
# Staff Payments Endpoints
# =============================================================================


@router.get(
    "/payments",
    response_model=StaffPaymentListResponse,
    status_code=status.HTTP_200_OK,
    summary="List payment records assigned to authenticated Staff",
)
def list_staff_payments(
    page: int = Query(default=1, ge=1, description="Page number (1-based)"),
    page_size: int = Query(default=20, ge=1, le=100, description="Items per page"),
    status_filter: Optional[str] = Query(
        default=None,
        alias="status",
        description="Filter by payment status (recorded, approved, rejected, voided)",
    ),
    search: Optional[str] = Query(
        default=None,
        description="Search by dealer name, invoice/reference number, or notes",
    ),
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> StaffPaymentListResponse:
    """
    Returns paginated payment records assigned to the authenticated Staff member:
    - Strictly scoped to records where staff_id == current_staff.id
    - Supports filtering by status: 'recorded', 'approved', 'rejected', 'voided'
    - Supports search across reference numbers, notes, and partner details
    - Deterministic newest-first sort (recorded_at DESC, id DESC)
    """
    base_query = (
        select(StaffPaymentRecord)
        .options(
            selectinload(StaffPaymentRecord.partner).selectinload(PartnerProfile.user),
            selectinload(StaffPaymentRecord.actor),
            selectinload(StaffPaymentRecord.status_history).selectinload(PaymentStatusHistory.actor),
        )
        .where(StaffPaymentRecord.staff_id == current_staff.id)
    )

    count_query = (
        select(func.count(StaffPaymentRecord.id))
        .where(StaffPaymentRecord.staff_id == current_staff.id)
    )

    if status_filter:
        clean_status = status_filter.strip().lower()
        base_query = base_query.where(StaffPaymentRecord.status == clean_status)
        count_query = count_query.where(StaffPaymentRecord.status == clean_status)

    if search and search.strip():
        term = f"%{search.strip()}%"
        search_filter = or_(
            StaffPaymentRecord.reference_number.ilike(term),
            StaffPaymentRecord.notes.ilike(term),
            StaffPaymentRecord.partner_id.in_(
                select(PartnerProfile.user_id)
                .join(User, User.id == PartnerProfile.user_id)
                .where(
                    or_(
                        PartnerProfile.business_name.ilike(term),
                        User.name.ilike(term),
                    )
                )
            ),
        )
        base_query = base_query.where(search_filter)
        count_query = count_query.where(search_filter)

    total = db.scalar(count_query) or 0
    total_pages = (total + page_size - 1) // page_size if total > 0 else 0
    offset = (page - 1) * page_size

    records = db.scalars(
        base_query
        .order_by(StaffPaymentRecord.recorded_at.desc(), StaffPaymentRecord.id.desc())
        .offset(offset)
        .limit(page_size)
    ).all()

    items = [build_payment_response(r) for r in records]

    return StaffPaymentListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        has_next=page < total_pages,
        has_prev=page > 1 and total_pages > 0,
    )


@router.get(
    "/payments/{payment_id}",
    response_model=StaffPaymentResponse,
    status_code=status.HTTP_200_OK,
    summary="Get single payment record detail",
)
def get_staff_payment_detail(
    payment_id: int,
    current_user: User = Depends(require_staff_or_admin),
    db: Session = Depends(get_db),
) -> StaffPaymentResponse:
    """
    Returns details for a single payment record:
    - Staff members can only access payment records assigned to them (staff_id == user.id)
    - Admins may access any payment record according to admin policy
    """
    payment = db.scalars(
        select(StaffPaymentRecord)
        .options(
            selectinload(StaffPaymentRecord.partner).selectinload(PartnerProfile.user),
            selectinload(StaffPaymentRecord.actor),
            selectinload(StaffPaymentRecord.status_history).selectinload(PaymentStatusHistory.actor),
        )
        .where(StaffPaymentRecord.id == payment_id)
    ).first()

    if payment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Payment record not found",
        )

    verify_staff_payment_access(payment, current_user)

    return build_payment_response(payment)


@router.post(
    "/payments/{payment_id}/approve",
    response_model=StaffPaymentResponse,
    status_code=status.HTTP_200_OK,
    summary="Approve a payment awaiting review",
)
def approve_staff_payment(
    payment_id: int,
    payload: Optional[StaffPaymentApproveRequest] = None,
    current_user: User = Depends(require_staff_or_admin),
    db: Session = Depends(get_db),
) -> StaffPaymentResponse:
    """
    Approves a payment record in 'recorded' status:
    - Concurrency-safe row locking
    - Authorized only for assigned Staff or Admin
    - Only valid from 'recorded' status
    - Appends audit trail to PaymentStatusHistory
    """
    payment = db.scalars(
        select(StaffPaymentRecord)
        .options(
            selectinload(StaffPaymentRecord.partner).selectinload(PartnerProfile.user),
            selectinload(StaffPaymentRecord.actor),
            selectinload(StaffPaymentRecord.status_history).selectinload(PaymentStatusHistory.actor),
        )
        .where(StaffPaymentRecord.id == payment_id)
        .with_for_update()
    ).first()

    if payment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Payment record not found",
        )

    verify_staff_payment_access(payment, current_user)

    remarks = payload.remarks.strip() if (payload and payload.remarks and payload.remarks.strip()) else "Payment approved"
    apply_payment_status_transition(
        db=db,
        payment=payment,
        target_status="approved",
        user=current_user,
        remarks=remarks,
    )

    return build_payment_response(payment)


@router.post(
    "/payments/{payment_id}/reject",
    response_model=StaffPaymentResponse,
    status_code=status.HTTP_200_OK,
    summary="Reject a payment awaiting review",
)
def reject_staff_payment(
    payment_id: int,
    payload: StaffPaymentRejectRequest,
    current_user: User = Depends(require_staff_or_admin),
    db: Session = Depends(get_db),
) -> StaffPaymentResponse:
    """
    Rejects a payment record in 'recorded' status:
    - Concurrency-safe row locking
    - Authorized only for assigned Staff or Admin
    - Requires non-empty rejection reason
    - Appends audit trail to PaymentStatusHistory
    """
    payment = db.scalars(
        select(StaffPaymentRecord)
        .options(
            selectinload(StaffPaymentRecord.partner).selectinload(PartnerProfile.user),
            selectinload(StaffPaymentRecord.actor),
            selectinload(StaffPaymentRecord.status_history).selectinload(PaymentStatusHistory.actor),
        )
        .where(StaffPaymentRecord.id == payment_id)
        .with_for_update()
    ).first()

    if payment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Payment record not found",
        )

    verify_staff_payment_access(payment, current_user)

    apply_payment_status_transition(
        db=db,
        payment=payment,
        target_status="rejected",
        user=current_user,
        remarks=payload.reason,
    )

    return build_payment_response(payment)
