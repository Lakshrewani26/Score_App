from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
import logging
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.security import get_current_active_user, require_partner, require_partner_or_staff_or_admin
from app.db.session import get_db
from app.models import Order, OrderItem, OrderStatusHistory, PartnerProfile, Product, User
from app.schemas.orders import (
    OrderCreateRequest,
    OrderItemCreate,
    OrderItemResponse,
    OrderPreviewItem,
    OrderPreviewResponse,
    OrderResponse,
    WhatsAppDeliveryResult,
)
from app.services.pdf_service import generate_order_pdf
from app.services.whatsapp_service import whatsapp_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/orders", tags=["partner-orders"])


def _build_order_response(order: Order) -> OrderResponse:
    partner = order.partner
    partner_profile: Optional[PartnerProfile] = getattr(partner, "partner_profile", None) if partner else None
    approver = order.approver

    items = order.items or []
    item_responses = [
        OrderItemResponse(
            id=item.id,
            product_id=item.product_id,
            product_code=item.product.product_code if item.product else f"PRD-{item.product_id}",
            product_name=item.product.name if item.product else f"Product #{item.product_id}",
            vehicle_type=item.product.vehicle_type if item.product else "",
            quantity=item.quantity,
            unit_price=Decimal(str(item.unit_price)),
            subtotal=Decimal(str(item.quantity * item.unit_price)),
        )
        for item in items
    ]

    total_qty = sum(item.quantity for item in items)
    order_total = sum(item.quantity * item.unit_price for item in items) if items else Decimal("0.00")

    return OrderResponse(
        id=order.id,
        order_number=order.order_number,
        partner_id=order.partner_id,
        partner_name=partner.name if partner else f"User #{order.partner_id}",
        business_name=partner_profile.business_name if partner_profile else None,
        business_address=partner_profile.business_address if partner_profile else None,
        partner_mobile=partner.mobile if partner else "",
        status=order.status,
        notes=order.notes,
        created_at=order.created_at,
        approved_by=order.approved_by,
        approved_by_name=approver.name if approver else None,
        approved_at=order.approved_at,
        item_count=len(items),
        total_quantity=total_qty,
        order_total=Decimal(str(order_total)),
        items=item_responses,
    )


def _generate_order_number(db: Session) -> str:
    today_str = datetime.now(timezone.utc).strftime("%Y%m%d")
    count_today = db.scalar(
        select(func.count(Order.id)).where(Order.order_number.like(f"ORD-{today_str}-%"))
    ) or 0
    seq = count_today + 1
    # Add random 4-char suffix to avoid race conditions
    rand_suffix = uuid.uuid4().hex[:4].upper()
    return f"ORD-{today_str}-{seq:04d}-{rand_suffix}"


@router.post("/preview", response_model=OrderPreviewResponse)
def preview_order_totals(
    payload: OrderCreateRequest,
    db: Session = Depends(get_db),
    current_partner: User = Depends(require_partner),
) -> OrderPreviewResponse:
    """
    Validates requested products and calculates authoritative server-side line totals
    and grand total without creating an order.
    Rejects any product without a valid price.
    """
    if not payload.items:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Order must contain at least one item.",
        )

    product_ids = [item.product_id for item in payload.items]
    products = db.scalars(select(Product).where(Product.id.in_(product_ids))).all()
    products_by_id = {p.id: p for p in products}

    preview_items: list[OrderPreviewItem] = []
    total_qty = 0
    grand_total = Decimal("0.00")

    for item in payload.items:
        if item.quantity <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Item quantity must be greater than zero (product ID {item.product_id}).",
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
                    f"Product '{product.name}' (Code: {product.product_code}) does not have an authorized price. "
                    "Order cannot be placed until pricing is configured by Admin."
                ),
            )

        unit_price = Decimal(str(product.price))
        subtotal = item.quantity * unit_price
        total_qty += item.quantity
        grand_total += subtotal

        preview_items.append(
            OrderPreviewItem(
                product_id=product.id,
                product_code=product.product_code,
                product_name=product.name,
                vehicle_type=product.vehicle_type,
                quantity=item.quantity,
                unit_price=unit_price,
                subtotal=subtotal,
            )
        )

    return OrderPreviewResponse(
        items=preview_items,
        item_count=len(preview_items),
        total_quantity=total_qty,
        grand_total=grand_total,
    )


@router.post("", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_partner_order(
    payload: OrderCreateRequest,
    idempotency_key_header: Optional[str] = Header(None, alias="Idempotency-Key"),
    db: Session = Depends(get_db),
    current_partner: User = Depends(require_partner),
) -> OrderResponse:
    """
    Submits a new partner order:
    1. Validates quantities and authoritative server-side prices.
    2. Derives partner identity strictly from authenticated JWT context.
    3. Prevents duplicate order creation via idempotency key.
    4. Persists the order and price snapshots.
    5. Sets status to 'pending_approval' (preserving staff/admin approval workflow).
    """
    if not payload.items:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Order must contain at least one item.",
        )

    # 1. Idempotency Check
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
                Order.partner_id == current_partner.id,
                Order.notes.contains(tag),
            )
        ).first()

        if existing_order:
            logger.info(
                "Duplicate order creation avoided for Partner #%s using idempotency key '%s'. Returning existing order #%s.",
                current_partner.id,
                idempotency_key,
                existing_order.order_number,
            )
            return _build_order_response(existing_order)

    # 2. Fetch products and validate prices server-side
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

    # 3. Build order record
    notes_parts = []
    if payload.notes and payload.notes.strip():
        notes_parts.append(payload.notes.strip())
    if idempotency_key:
        notes_parts.append(f"[idempotency_key:{idempotency_key}]")
    full_notes = "\n".join(notes_parts) if notes_parts else None

    order_number = _generate_order_number(db)
    new_order = Order(
        order_number=order_number,
        partner_id=current_partner.id,
        status="pending_approval",
        notes=full_notes,
    )
    db.add(new_order)
    db.flush()  # Populate new_order.id

    for item in order_items_to_create:
        item.order_id = new_order.id
        db.add(item)

    # 4. Status history record
    history_entry = OrderStatusHistory(
        order_id=new_order.id,
        old_status=None,
        new_status="pending_approval",
        changed_by=current_partner.id,
        remarks="Order placed by Partner through Score App",
    )
    db.add(history_entry)

    db.commit()

    # 5. Reload with full relations
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


@router.get("", response_model=list[OrderResponse])
def list_partner_orders(
    db: Session = Depends(get_db),
    current_partner: User = Depends(require_partner),
) -> list[OrderResponse]:
    """
    Returns list of orders placed by the authenticated partner, ordered newest first.
    """
    orders = db.scalars(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.approver),
            selectinload(Order.items).selectinload(OrderItem.product),
        )
        .where(Order.partner_id == current_partner.id)
        .order_by(Order.created_at.desc(), Order.id.desc())
    ).all()

    return [_build_order_response(order) for order in orders]


@router.get("/{order_id}", response_model=OrderResponse)
def get_order_detail(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_partner_or_staff_or_admin),
) -> OrderResponse:
    """
    Fetches single order detail.
    Authorized for the order's partner or staff/admin.
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
        raise HTTPException(status_code=404, detail="Order not found")

    if current_user.role == "partner" and order.partner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You are not authorized to view another partner's order.",
        )

    return _build_order_response(order)


@router.get("/{order_id}/pdf")
def download_order_pdf(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_partner_or_staff_or_admin),
) -> Response:
    """
    Generates and returns the official order PDF for the persisted order.
    Protected so partners can only download their own order.
    """
    order = db.scalars(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.items).selectinload(OrderItem.product),
        )
        .where(Order.id == order_id)
    ).first()

    if order is None:
        raise HTTPException(status_code=404, detail="Order not found")

    if current_user.role == "partner" and order.partner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You are not authorized to download this order PDF.",
        )

    pdf_bytes = generate_order_pdf(order)
    filename = f"Score_Order_{order.order_number}.pdf"

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="{filename}"',
            "Cache-Control": "private, no-cache, no-store, must-revalidate",
        },
    )


@router.post("/{order_id}/send-whatsapp", response_model=WhatsAppDeliveryResult)
def send_order_whatsapp(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_partner_or_staff_or_admin),
) -> WhatsAppDeliveryResult:
    """
    Dispatches the generated order PDF via WhatsApp Cloud API.
    Does NOT recreate or mutate the persisted order.
    Can be safely retried.
    """
    order = db.scalars(
        select(Order)
        .options(
            selectinload(Order.partner).selectinload(User.partner_profile),
            selectinload(Order.items).selectinload(OrderItem.product),
        )
        .where(Order.id == order_id)
    ).first()

    if order is None:
        raise HTTPException(status_code=404, detail="Order not found")

    if current_user.role == "partner" and order.partner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You are not authorized to dispatch this order.",
        )

    try:
        pdf_bytes = generate_order_pdf(order)
    except Exception as exc:
        logger.exception("Failed to generate PDF for WhatsApp delivery: %s", str(exc))
        return WhatsAppDeliveryResult(
            success=False,
            status="pdf_generation_failed",
            message=f"Failed to generate order PDF: {str(exc)}",
            recipient=order.partner.mobile if order.partner else None,
            provider=whatsapp_service.provider,
            message_id=None,
        )

    result = whatsapp_service.send_order_pdf(order, pdf_bytes)
    return result
