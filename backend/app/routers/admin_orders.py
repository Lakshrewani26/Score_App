from __future__ import annotations

from datetime import datetime, time, timezone
from decimal import Decimal
from typing import Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.security import require_admin
from app.db.session import get_db
from app.models import (
    Order,
    OrderItem,
    OrderStatusHistory,
    PartnerProfile,
    Product,
    StockRequest,
    StockRequestItem,
    StockRequestStatusHistory,
    User,
)
from app.schemas.admin_orders import (
    AdminOrderDetail,
    AdminOrderItemDetail,
    AdminOrderStatusHistoryItem,
    AdminOrderStatusUpdateRequest,
    AdminOrderSummary,
    AdminStockRequestDetail,
    AdminStockRequestItemDetail,
    AdminStockRequestStatusHistoryItem,
    AdminStockRequestSummary,
    PaginatedOrdersResponse,
    PaginatedStockRequestsResponse,
    PaginationMetadata,
)
from app.services.order_service import apply_order_status_transition

router = APIRouter(prefix="/api/v1/admin", tags=["admin-orders"])


def _parse_date(date_str: Optional[str], is_end_of_day: bool = False) -> Optional[datetime]:
    """Parse an ISO date or datetime string safely."""
    if not date_str:
        return None
    cleaned = date_str.strip()
    if not cleaned:
        return None

    try:
        # Check if full ISO format with T
        if "T" in cleaned:
            dt = datetime.fromisoformat(cleaned.replace("Z", "+00:00"))
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        # Date only (YYYY-MM-DD)
        parsed_date = datetime.strptime(cleaned, "%Y-%m-%d").date()
        target_time = time(23, 59, 59, 999999) if is_end_of_day else time(0, 0, 0, 0)
        return datetime.combine(parsed_date, target_time, tzinfo=timezone.utc)
    except (ValueError, TypeError):
        return None


def _build_order_summary(order: Order) -> AdminOrderSummary:
    partner = order.partner
    partner_profile: Optional[PartnerProfile] = getattr(partner, "partner_profile", None) if partner else None
    approver = order.approver

    items = order.items or []
    item_count = len(items)
    total_quantity = sum(item.quantity for item in items)
    order_total = (
        order.final_total
        if order.final_total is not None
        else sum(item.quantity * item.unit_price for item in items)
    )

    return AdminOrderSummary(
        id=order.id,
        order_number=order.order_number,
        partner_id=order.partner_id,
        partner_name=partner.name if partner else f"User #{order.partner_id}",
        business_name=partner_profile.business_name if partner_profile else None,
        partner_mobile=partner.mobile if partner else "",
        status=order.status,
        notes=order.notes,
        created_at=order.created_at,
        approved_by=order.approved_by,
        approved_by_name=approver.name if approver else None,
        approved_at=order.approved_at,
        item_count=item_count,
        total_quantity=total_quantity,
        order_total=Decimal(str(order_total)),
        subtotal_before_discount=(
            Decimal(str(order.subtotal_before_discount))
            if order.subtotal_before_discount is not None
            else Decimal(str(order_total))
        ),
        discount_percentage=(
            Decimal(str(order.discount_percentage))
            if order.discount_percentage is not None
            else Decimal("0.00")
        ),
        total_discount=(
            Decimal(str(order.total_discount))
            if order.total_discount is not None
            else Decimal("0.00")
        ),
        final_total=(
            Decimal(str(order.final_total))
            if order.final_total is not None
            else Decimal(str(order_total))
        ),
    )


def _build_order_detail(order: Order) -> AdminOrderDetail:
    summary = _build_order_summary(order)

    items_detail = [
        AdminOrderItemDetail(
            id=item.id,
            product_id=item.product_id,
            product_code=item.product.product_code if item.product else "",
            product_name=item.product.name if item.product else "",
            vehicle_type=item.product.vehicle_type if item.product else "",
            quantity=item.quantity,
            unit_price=item.unit_price,
            subtotal=item.quantity * item.unit_price,
            original_price=item.original_price if item.original_price is not None else item.unit_price,
            discount_percentage=item.discount_percentage if item.discount_percentage is not None else Decimal("0.00"),
            discount_amount=item.discount_amount if item.discount_amount is not None else Decimal("0.00"),
            discounted_price=item.discounted_price if item.discounted_price is not None else item.unit_price,
        )
        for item in (order.items or [])
    ]

    history_items = [
        AdminOrderStatusHistoryItem(
            id=hist.id,
            old_status=hist.old_status,
            new_status=hist.new_status,
            changed_by=hist.changed_by,
            changed_by_name=hist.actor.name if hist.actor else None,
            changed_at=hist.changed_at,
            remarks=hist.remarks,
        )
        for hist in sorted(order.status_history or [], key=lambda h: h.changed_at)
    ]

    return AdminOrderDetail(
        **summary.model_dump(),
        items=items_detail,
        status_history=history_items,
    )


def _build_stock_request_summary(req: StockRequest) -> AdminStockRequestSummary:
    partner = req.partner
    partner_profile: Optional[PartnerProfile] = getattr(partner, "partner_profile", None) if partner else None
    reviewer = req.reviewer

    items = req.items or []
    item_count = len(items)
    total_quantity = sum(item.quantity for item in items)

    return AdminStockRequestSummary(
        id=req.id,
        request_number=req.request_number,
        partner_id=req.partner_id,
        partner_name=partner.name if partner else f"User #{req.partner_id}",
        business_name=partner_profile.business_name if partner_profile else None,
        partner_mobile=partner.mobile if partner else "",
        status=req.status,
        notes=req.notes,
        created_at=req.created_at,
        reviewed_by=req.reviewed_by,
        reviewed_by_name=reviewer.name if reviewer else None,
        reviewed_at=req.reviewed_at,
        item_count=item_count,
        total_quantity=total_quantity,
    )


def _build_stock_request_detail(req: StockRequest) -> AdminStockRequestDetail:
    summary = _build_stock_request_summary(req)

    items_detail = [
        AdminStockRequestItemDetail(
            id=item.id,
            product_id=item.product_id,
            product_code=item.product.product_code if item.product else "",
            product_name=item.product.name if item.product else "",
            vehicle_type=item.product.vehicle_type if item.product else "",
            quantity=item.quantity,
        )
        for item in (req.items or [])
    ]

    history_items = [
        AdminStockRequestStatusHistoryItem(
            id=hist.id,
            old_status=hist.old_status,
            new_status=hist.new_status,
            changed_by=hist.changed_by,
            changed_by_name=hist.actor.name if hist.actor else None,
            changed_at=hist.changed_at,
            remarks=hist.remarks,
        )
        for hist in sorted(req.status_history or [], key=lambda h: h.changed_at)
    ]

    return AdminStockRequestDetail(
        **summary.model_dump(),
        items=items_detail,
        status_history=history_items,
    )


# ===========================================================================
# Orders Endpoints
# ===========================================================================

@router.get("/orders", response_model=PaginatedOrdersResponse)
def list_orders(
    search: Optional[str] = Query(default=None, description="Search by order number or partner info"),
    status: Optional[str] = Query(default=None, description="Filter by order status"),
    vehicle_type: Optional[Literal["2-Wheeler", "3-Wheeler", "Both"]] = Query(
        default=None, description="Filter by vehicle type contained in order items"
    ),
    date_from: Optional[str] = Query(default=None, description="Filter orders created on or after (YYYY-MM-DD)"),
    date_to: Optional[str] = Query(default=None, description="Filter orders created on or before (YYYY-MM-DD)"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PaginatedOrdersResponse:
    """
    List partner orders with search, multi-criteria filtering, pagination,
    and eager-loaded relationships to avoid N+1 queries.
    """
    filters = []

    if status:
        filters.append(Order.status == status)

    if vehicle_type:
        if vehicle_type in ("2-Wheeler", "3-Wheeler"):
            filters.append(
                Order.items.any(
                    OrderItem.product.has(
                        Product.vehicle_type.in_([vehicle_type, "Both"])
                    )
                )
            )
        else:
            filters.append(
                Order.items.any(
                    OrderItem.product.has(
                        Product.vehicle_type == "Both"
                    )
                )
            )

    parsed_date_from = _parse_date(date_from, is_end_of_day=False)
    if parsed_date_from:
        filters.append(Order.created_at >= parsed_date_from)

    parsed_date_to = _parse_date(date_to, is_end_of_day=True)
    if parsed_date_to:
        filters.append(Order.created_at <= parsed_date_to)

    if search:
        clean_search = search.strip()
        if clean_search:
            pattern = f"%{clean_search}%"
            search_clause = (
                Order.order_number.ilike(pattern)
                | Order.partner.has(User.name.ilike(pattern))
                | Order.partner.has(User.mobile.ilike(pattern))
                | Order.partner.has(
                    User.partner_profile.has(PartnerProfile.business_name.ilike(pattern))
                )
            )
            filters.append(search_clause)

    total = db.scalar(
        select(func.count()).select_from(Order).where(*filters)
    ) or 0

    total_pages = (total + page_size - 1) // page_size if total > 0 else 0
    offset = (page - 1) * page_size

    orders = db.scalars(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
        )
        .where(*filters)
        .order_by(Order.created_at.desc(), Order.id.desc())
        .offset(offset)
        .limit(page_size)
    ).all()

    items = [_build_order_summary(o) for o in orders]
    meta = PaginationMetadata(
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )
    return PaginatedOrdersResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        pagination=meta,
    )


@router.get("/orders/{order_id}", response_model=AdminOrderDetail)
def get_order_detail(
    order_id: int,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminOrderDetail:
    """Retrieve full details of a single order, its items, and status audit history."""
    order = db.scalar(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
            selectinload(Order.status_history).selectinload(OrderStatusHistory.actor),
        )
        .where(Order.id == order_id)
    )
    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Order #{order_id} not found",
        )

    return _build_order_detail(order)


@router.patch("/orders/{order_id}/status", response_model=AdminOrderDetail)
def update_order_status(
    order_id: int,
    payload: AdminOrderStatusUpdateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminOrderDetail:
    """
    Manage order progression after Staff approval:
    approved_processing -> dispatched -> delivered.

    Admin cannot bypass Staff approval for 'pending_approval' orders.
    Admin cannot modify orders that are already terminal ('delivered', 'rejected').
    """
    order = db.scalar(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
            selectinload(Order.status_history).selectinload(OrderStatusHistory.actor),
        )
        .where(Order.id == order_id)
        .with_for_update()
    )
    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Order #{order_id} not found",
        )

    apply_order_status_transition(
        db=db,
        order=order,
        target_status=payload.status,
        user=current_admin,
        remarks=payload.remarks,
    )

    # Re-fetch order with refreshed relations
    updated_order = db.scalar(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
            selectinload(Order.status_history).selectinload(OrderStatusHistory.actor),
        )
        .where(Order.id == order_id)
    )
    return _build_order_detail(updated_order or order)


# ===========================================================================
# Stock Requests Endpoints (Read-Only for Admin)
# ===========================================================================

@router.get("/stock-requests", response_model=PaginatedStockRequestsResponse)
def list_stock_requests(
    search: Optional[str] = Query(default=None, description="Search by request number or partner info"),
    status: Optional[str] = Query(default=None, description="Filter by stock request status"),
    date_from: Optional[str] = Query(default=None, description="Filter requests created on or after (YYYY-MM-DD)"),
    date_to: Optional[str] = Query(default=None, description="Filter requests created on or before (YYYY-MM-DD)"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PaginatedStockRequestsResponse:
    """
    List partner stock requests with multi-field search, status filtering,
    date range filtering, and pagination. (Read-only for Admin).
    """
    filters = []

    if status:
        filters.append(StockRequest.status == status)

    parsed_date_from = _parse_date(date_from, is_end_of_day=False)
    if parsed_date_from:
        filters.append(StockRequest.created_at >= parsed_date_from)

    parsed_date_to = _parse_date(date_to, is_end_of_day=True)
    if parsed_date_to:
        filters.append(StockRequest.created_at <= parsed_date_to)

    if search:
        clean_search = search.strip()
        if clean_search:
            pattern = f"%{clean_search}%"
            search_clause = (
                StockRequest.request_number.ilike(pattern)
                | StockRequest.partner.has(User.name.ilike(pattern))
                | StockRequest.partner.has(User.mobile.ilike(pattern))
                | StockRequest.partner.has(
                    User.partner_profile.has(PartnerProfile.business_name.ilike(pattern))
                )
            )
            filters.append(search_clause)

    total = db.scalar(
        select(func.count()).select_from(StockRequest).where(*filters)
    ) or 0

    total_pages = (total + page_size - 1) // page_size if total > 0 else 0
    offset = (page - 1) * page_size

    requests = db.scalars(
        select(StockRequest)
        .options(
            selectinload(StockRequest.partner).selectinload(User.partner_profile),
            selectinload(StockRequest.reviewer),
            selectinload(StockRequest.items).selectinload(StockRequestItem.product),
        )
        .where(*filters)
        .order_by(StockRequest.created_at.desc(), StockRequest.id.desc())
        .offset(offset)
        .limit(page_size)
    ).all()

    items = [_build_stock_request_summary(r) for r in requests]
    meta = PaginationMetadata(
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )
    return PaginatedStockRequestsResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        pagination=meta,
    )


@router.get("/stock-requests/{request_id}", response_model=AdminStockRequestDetail)
def get_stock_request_detail(
    request_id: int,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminStockRequestDetail:
    """Retrieve full details of a single stock request, requested items, and review status."""
    stock_req = db.scalar(
        select(StockRequest)
        .options(
            selectinload(StockRequest.partner).selectinload(User.partner_profile),
            selectinload(StockRequest.reviewer),
            selectinload(StockRequest.items).selectinload(StockRequestItem.product),
            selectinload(StockRequest.status_history).selectinload(StockRequestStatusHistory.actor),
        )
        .where(StockRequest.id == request_id)
    )
    if stock_req is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Stock request #{request_id} not found",
        )

    return _build_stock_request_detail(stock_req)
