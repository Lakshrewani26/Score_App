from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import case, distinct, func, select, union
from sqlalchemy.orm import Session

from app.core.security import require_admin
from app.db.session import get_db
from app.models import (
    Order,
    OrderItem,
    PartnerProfile,
    Product,
    ProductCategory,
    StaffPartnerAssignment,
    StaffPaymentRecord,
    StaffProfile,
    StockRequest,
    User,
    Zone,
)
from app.schemas.admin_reports import (
    AdminReportOverviewResponse,
    AreaWiseReportItem,
    AreaWiseReportResponse,
    CatalogueSummary,
    OrderTrendPoint,
    PartnerWiseReportItem,
    PartnerWiseReportResponse,
    ReportDateFilter,
    ReportOverview,
    StaffWiseReportItem,
    StaffWiseReportResponse,
    StatusCount,
    ZoneWiseReportItem,
    ZoneWiseReportResponse,
)

router = APIRouter(prefix="/api/v1/admin", tags=["admin-reports"])

VALID_PRESETS = {"7d", "30d", "90d", "all_time", "custom"}
VALID_INTERVALS = {"daily", "weekly", "monthly"}

ORDER_STATUS_LABELS = [
    ("pending_approval", "Pending Approval"),
    ("approved_processing", "Processing"),
    ("dispatched", "Dispatched"),
    ("delivered", "Delivered"),
    ("rejected", "Rejected"),
    ("cancelled", "Cancelled"),
]

STOCK_REQUEST_STATUS_LABELS = [
    ("pending_approval", "Pending Approval"),
    ("approved", "Approved"),
    ("rejected", "Rejected"),
]


def _parse_filter_date(date_str: Optional[str], is_end_of_day: bool = False) -> Optional[datetime]:
    if not date_str:
        return None
    cleaned = date_str.strip()
    if not cleaned:
        return None

    try:
        if "T" in cleaned:
            dt = datetime.fromisoformat(cleaned.replace("Z", "+00:00"))
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        parsed_date = datetime.strptime(cleaned, "%Y-%m-%d").date()
        target_time = time(23, 59, 59, 999999) if is_end_of_day else time(0, 0, 0, 0)
        return datetime.combine(parsed_date, target_time, tzinfo=timezone.utc)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid date format: '{date_str}'. Expected format is YYYY-MM-DD or ISO 8601.",
        )


@router.get("/reports/overview", response_model=AdminReportOverviewResponse)
def get_report_overview(
    preset: Optional[str] = Query(None, description="Preset window: 7d, 30d, 90d, all_time, custom"),
    date_from: Optional[str] = Query(None, description="Start date (inclusive)"),
    date_to: Optional[str] = Query(None, description="End date (inclusive)"),
    interval: Optional[str] = Query(None, description="Trend grouping interval: daily, weekly, monthly"),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminReportOverviewResponse:
    now_utc = datetime.now(timezone.utc)

    # 1. Validate preset & interval if provided
    if preset is not None and preset.lower() not in VALID_PRESETS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported preset '{preset}'. Supported presets are: {', '.join(sorted(VALID_PRESETS))}.",
        )
    preset_norm = preset.lower() if preset else None

    if interval is not None and interval.lower() not in VALID_INTERVALS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported interval '{interval}'. Supported intervals are: {', '.join(sorted(VALID_INTERVALS))}.",
        )
    interval_norm = interval.lower() if interval else None

    # 2. Determine date window
    parsed_date_from: Optional[datetime] = None
    parsed_date_to: Optional[datetime] = None

    if date_from:
        parsed_date_from = _parse_filter_date(date_from, is_end_of_day=False)
    if date_to:
        parsed_date_to = _parse_filter_date(date_to, is_end_of_day=True)

    # If preset is provided, it dictates the window unless custom
    if preset_norm == "7d":
        parsed_date_to = datetime.combine(now_utc.date(), time(23, 59, 59, 999999), tzinfo=timezone.utc)
        parsed_date_from = datetime.combine(now_utc.date() - timedelta(days=6), time(0, 0, 0, 0), tzinfo=timezone.utc)
    elif preset_norm == "30d":
        parsed_date_to = datetime.combine(now_utc.date(), time(23, 59, 59, 999999), tzinfo=timezone.utc)
        parsed_date_from = datetime.combine(now_utc.date() - timedelta(days=29), time(0, 0, 0, 0), tzinfo=timezone.utc)
    elif preset_norm == "90d":
        parsed_date_to = datetime.combine(now_utc.date(), time(23, 59, 59, 999999), tzinfo=timezone.utc)
        parsed_date_from = datetime.combine(now_utc.date() - timedelta(days=89), time(0, 0, 0, 0), tzinfo=timezone.utc)
    elif preset_norm == "all_time":
        parsed_date_from = None
        parsed_date_to = None
    elif preset_norm == "custom":
        if not parsed_date_from and not parsed_date_to:
            # Default custom to last 30 days if neither provided
            parsed_date_to = datetime.combine(now_utc.date(), time(23, 59, 59, 999999), tzinfo=timezone.utc)
            parsed_date_from = datetime.combine(now_utc.date() - timedelta(days=29), time(0, 0, 0, 0), tzinfo=timezone.utc)
    else:
        # No preset explicitly specified: if dates provided, custom; else default to 30d
        if parsed_date_from or parsed_date_to:
            preset_norm = "custom"
        else:
            preset_norm = "30d"
            parsed_date_to = datetime.combine(now_utc.date(), time(23, 59, 59, 999999), tzinfo=timezone.utc)
            parsed_date_from = datetime.combine(now_utc.date() - timedelta(days=29), time(0, 0, 0, 0), tzinfo=timezone.utc)

    # Validate range ordering
    if parsed_date_from and parsed_date_to and parsed_date_from > parsed_date_to:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date range: date_from must be earlier than or equal to date_to.",
        )

    # Automatically choose interval if not provided
    if not interval_norm:
        if parsed_date_from and parsed_date_to:
            span_days = (parsed_date_to.date() - parsed_date_from.date()).days
            if span_days <= 31:
                interval_norm = "daily"
            elif span_days <= 120:
                interval_norm = "weekly"
            else:
                interval_norm = "monthly"
        else:
            interval_norm = "monthly"

    # 3. Aggregate Orders
    order_filter = []
    if parsed_date_from:
        order_filter.append(Order.created_at >= parsed_date_from)
    if parsed_date_to:
        order_filter.append(Order.created_at <= parsed_date_to)

    order_status_query = select(Order.status, func.count(Order.id))
    if order_filter:
        order_status_query = order_status_query.where(*order_filter)
    order_status_query = order_status_query.group_by(Order.status)
    order_status_rows = db.execute(order_status_query).all()
    order_counts_by_status = {row[0]: row[1] for row in order_status_rows}

    total_orders = sum(order_counts_by_status.values())
    orders_pending_approval = order_counts_by_status.get("pending_approval", 0)
    orders_processing = order_counts_by_status.get("approved_processing", 0)
    orders_dispatched = order_counts_by_status.get("dispatched", 0)
    orders_delivered = order_counts_by_status.get("delivered", 0)
    orders_rejected = order_counts_by_status.get("rejected", 0)
    orders_cancelled = order_counts_by_status.get("cancelled", 0)

    order_status_distribution = [
        StatusCount(status=status_key, label=label, count=order_counts_by_status.get(status_key, 0))
        for status_key, label in ORDER_STATUS_LABELS
    ]

    # Total order value (sum of OrderItem quantity * unit_price for approved orders in range)
    # Includes: approved_processing, dispatched, delivered. Excludes: pending_approval, rejected, cancelled.
    order_value_query = (
        select(func.coalesce(func.sum(OrderItem.quantity * OrderItem.unit_price), 0))
        .select_from(OrderItem)
        .join(Order, OrderItem.order_id == Order.id)
        .where(Order.status.in_(["approved_processing", "dispatched", "delivered"]))
    )
    if order_filter:
        order_value_query = order_value_query.where(*order_filter)
    total_order_value = db.scalar(order_value_query) or Decimal("0.00")

    # 4. Aggregate Stock Requests
    sr_filter = []
    if parsed_date_from:
        sr_filter.append(StockRequest.created_at >= parsed_date_from)
    if parsed_date_to:
        sr_filter.append(StockRequest.created_at <= parsed_date_to)

    sr_status_query = select(StockRequest.status, func.count(StockRequest.id))
    if sr_filter:
        sr_status_query = sr_status_query.where(*sr_filter)
    sr_status_query = sr_status_query.group_by(StockRequest.status)
    sr_status_rows = db.execute(sr_status_query).all()
    sr_counts_by_status = {row[0]: row[1] for row in sr_status_rows}

    total_stock_requests = sum(sr_counts_by_status.values())
    stock_requests_pending_approval = sr_counts_by_status.get("pending_approval", 0)
    stock_requests_approved = sr_counts_by_status.get("approved", 0)
    stock_requests_rejected = sr_counts_by_status.get("rejected", 0)

    stock_request_status_distribution = [
        StatusCount(status=status_key, label=label, count=sr_counts_by_status.get(status_key, 0))
        for status_key, label in STOCK_REQUEST_STATUS_LABELS
    ]

    # 5. Catalogue Summary (Current Snapshot)
    prod_stmt = select(
        func.count(Product.id).label("total"),
        func.coalesce(func.sum(case((Product.is_active.is_(True), 1), else_=0)), 0).label("active"),
        func.coalesce(func.sum(case((Product.is_active.is_(False), 1), else_=0)), 0).label("inactive"),
        func.coalesce(func.sum(case((Product.price.is_(None), 1), else_=0)), 0).label("null_price"),
    )
    prod_row = db.execute(prod_stmt).one()

    cat_stmt = select(
        func.count(ProductCategory.id).label("total"),
        func.coalesce(func.sum(case((ProductCategory.is_active.is_(True), 1), else_=0)), 0).label("active"),
        func.coalesce(func.sum(case((ProductCategory.is_active.is_(False), 1), else_=0)), 0).label("inactive"),
    )
    cat_row = db.execute(cat_stmt).one()

    catalogue_summary = CatalogueSummary(
        total_products=prod_row.total,
        active_products=prod_row.active,
        inactive_products=prod_row.inactive,
        total_categories=cat_row.total,
        active_categories=cat_row.active,
        inactive_categories=cat_row.inactive,
        products_with_null_price=prod_row.null_price,
    )

    # 6. Order Trends Aggregation
    order_trends: list[OrderTrendPoint] = []

    # Query daily order counts
    daily_count_query = select(func.date(Order.created_at).label("d"), func.count(Order.id))
    if order_filter:
        daily_count_query = daily_count_query.where(*order_filter)
    daily_count_query = daily_count_query.group_by(func.date(Order.created_at))
    daily_counts = {str(row[0]): row[1] for row in db.execute(daily_count_query).all()}

    # Query daily order values (for approved orders)
    daily_val_query = (
        select(
            func.date(Order.created_at).label("d"),
            func.coalesce(func.sum(OrderItem.quantity * OrderItem.unit_price), 0),
        )
        .select_from(OrderItem)
        .join(Order, OrderItem.order_id == Order.id)
        .where(Order.status.in_(["approved_processing", "dispatched", "delivered"]))
    )
    if order_filter:
        daily_val_query = daily_val_query.where(*order_filter)
    daily_val_query = daily_val_query.group_by(func.date(Order.created_at))
    daily_values = {str(row[0]): Decimal(str(row[1])) for row in db.execute(daily_val_query).all()}

    # Generate trend points
    if interval_norm == "daily":
        start_date = parsed_date_from.date() if parsed_date_from else None
        end_date = parsed_date_to.date() if parsed_date_to else None

        if not start_date or not end_date:
            # All time without date boundaries: find min date
            min_date_str = min(daily_counts.keys()) if daily_counts else None
            if min_date_str:
                start_date = datetime.strptime(min_date_str[:10], "%Y-%m-%d").date()
                end_date = now_utc.date()
            else:
                start_date = now_utc.date() - timedelta(days=6)
                end_date = now_utc.date()

        # Cap daily trend points to avoid excessive payload
        span = (end_date - start_date).days
        if span > 120:
            # Fall back to weekly for very large daily requests
            interval_norm = "weekly"

    if interval_norm == "daily":
        cur = start_date
        while cur <= end_date:
            d_str = cur.strftime("%Y-%m-%d")
            c = daily_counts.get(d_str, 0)
            v = daily_values.get(d_str, Decimal("0.00"))
            label = cur.strftime("%d %b")
            order_trends.append(
                OrderTrendPoint(
                    period=d_str,
                    label=label,
                    count=c,
                    total_value=v,
                )
            )
            cur += timedelta(days=1)

    elif interval_norm == "weekly":
        start_date = parsed_date_from.date() if parsed_date_from else None
        end_date = parsed_date_to.date() if parsed_date_to else None
        if not start_date or not end_date:
            min_date_str = min(daily_counts.keys()) if daily_counts else None
            if min_date_str:
                start_date = datetime.strptime(min_date_str[:10], "%Y-%m-%d").date()
                end_date = now_utc.date()
            else:
                start_date = now_utc.date() - timedelta(days=28)
                end_date = now_utc.date()

        # Bucket into 7-day windows
        cur = start_date
        while cur <= end_date:
            week_end = min(cur + timedelta(days=6), end_date)
            w_count = 0
            w_value = Decimal("0.00")
            day_cursor = cur
            while day_cursor <= week_end:
                d_str = day_cursor.strftime("%Y-%m-%d")
                w_count += daily_counts.get(d_str, 0)
                w_value += daily_values.get(d_str, Decimal("0.00"))
                day_cursor += timedelta(days=1)

            label = f"{cur.strftime('%d %b')} - {week_end.strftime('%d %b')}"
            period_key = f"{cur.strftime('%Y-%m-%d')}"
            order_trends.append(
                OrderTrendPoint(
                    period=period_key,
                    label=label,
                    count=w_count,
                    total_value=w_value,
                )
            )
            cur += timedelta(days=7)

    elif interval_norm == "monthly":
        start_date = parsed_date_from.date() if parsed_date_from else None
        end_date = parsed_date_to.date() if parsed_date_to else None
        if not start_date or not end_date:
            min_date_str = min(daily_counts.keys()) if daily_counts else None
            if min_date_str:
                start_date = datetime.strptime(min_date_str[:10], "%Y-%m-%d").date()
                end_date = now_utc.date()
            else:
                start_date = now_utc.date() - timedelta(days=180)
                end_date = now_utc.date()

        # Bucket by calendar month
        cur_year = start_date.year
        cur_month = start_date.month
        end_year = end_date.year
        end_month = end_date.month

        # Group daily data by YYYY-MM
        monthly_counts: dict[str, int] = {}
        monthly_values: dict[str, Decimal] = {}
        for d_str, count in daily_counts.items():
            m_key = d_str[:7]
            monthly_counts[m_key] = monthly_counts.get(m_key, 0) + count
        for d_str, val in daily_values.items():
            m_key = d_str[:7]
            monthly_values[m_key] = monthly_values.get(m_key, Decimal("0.00")) + val

        while (cur_year < end_year) or (cur_year == end_year and cur_month <= end_month):
            m_key = f"{cur_year:04d}-{cur_month:02d}"
            m_date = date(cur_year, cur_month, 1)
            label = m_date.strftime("%b %Y")
            order_trends.append(
                OrderTrendPoint(
                    period=m_key,
                    label=label,
                    count=monthly_counts.get(m_key, 0),
                    total_value=monthly_values.get(m_key, Decimal("0.00")),
                )
            )
            cur_month += 1
            if cur_month > 12:
                cur_month = 1
                cur_year += 1

    overview = ReportOverview(
        total_orders=total_orders,
        orders_pending_approval=orders_pending_approval,
        orders_processing=orders_processing,
        orders_dispatched=orders_dispatched,
        orders_delivered=orders_delivered,
        orders_rejected=orders_rejected,
        orders_cancelled=orders_cancelled,
        total_stock_requests=total_stock_requests,
        stock_requests_pending_approval=stock_requests_pending_approval,
        stock_requests_approved=stock_requests_approved,
        stock_requests_rejected=stock_requests_rejected,
        total_order_value=Decimal(str(total_order_value)),
    )

    date_filter = ReportDateFilter(
        preset=preset_norm,
        date_from=parsed_date_from,
        date_to=parsed_date_to,
        interval=interval_norm,
    )

    return AdminReportOverviewResponse(
        generated_at=now_utc,
        filter=date_filter,
        overview=overview,
        catalogue_summary=catalogue_summary,
        order_status_distribution=order_status_distribution,
        stock_request_status_distribution=stock_request_status_distribution,
        order_trends=order_trends,
    )


# ---------------------------------------------------------------------------
# Zone-Wise Report
# ---------------------------------------------------------------------------

@router.get("/reports/zone-wise", response_model=ZoneWiseReportResponse)
def get_zone_wise_report(
    date_from: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    date_to: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    zone_id: Optional[int] = Query(None, description="Filter by Zone ID"),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ZoneWiseReportResponse:
    parsed_date_from = _parse_filter_date(date_from, is_end_of_day=False)
    parsed_date_to = _parse_filter_date(date_to, is_end_of_day=True)

    if parsed_date_from and parsed_date_to and parsed_date_from > parsed_date_to:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_from must be earlier than or equal to date_to.",
        )

    # 1. Fetch relevant zones
    zones_query = select(Zone).order_by(Zone.name.asc())
    if zone_id is not None:
        zones_query = zones_query.where(Zone.id == zone_id)
    zones = db.scalars(zones_query).all()

    items: list[ZoneWiseReportItem] = []
    total_all_orders = 0
    total_all_order_value = Decimal("0.00")

    for z in zones:
        # Partners in this zone
        partner_user_ids = db.scalars(
            select(PartnerProfile.user_id).where(PartnerProfile.zone_id == z.id)
        ).all()
        partner_count = len(partner_user_ids)

        order_count = 0
        total_order_value = Decimal("0.00")
        if partner_user_ids:
            order_filters = [Order.partner_id.in_(partner_user_ids)]
            if parsed_date_from:
                order_filters.append(Order.created_at >= parsed_date_from)
            if parsed_date_to:
                order_filters.append(Order.created_at <= parsed_date_to)

            order_count = db.scalar(
                select(func.count(Order.id)).where(*order_filters)
            ) or 0

            val = db.scalar(
                select(func.coalesce(func.sum(OrderItem.quantity * OrderItem.unit_price), 0))
                .select_from(OrderItem)
                .join(Order, OrderItem.order_id == Order.id)
                .where(Order.status.in_(["approved_processing", "dispatched", "delivered"]), *order_filters)
            )
            total_order_value = Decimal(str(val or 0))

        # Payments for partners in this zone
        payment_count = 0
        total_payments_collected = Decimal("0.00")
        if partner_user_ids:
            payment_filters = [
                StaffPaymentRecord.partner_id.in_(partner_user_ids),
                StaffPaymentRecord.status == "approved",
            ]
            if parsed_date_from:
                payment_filters.append(StaffPaymentRecord.recorded_at >= parsed_date_from)
            if parsed_date_to:
                payment_filters.append(StaffPaymentRecord.recorded_at <= parsed_date_to)

            payment_count = db.scalar(
                select(func.count(StaffPaymentRecord.id)).where(*payment_filters)
            ) or 0
            pval = db.scalar(
                select(func.coalesce(func.sum(StaffPaymentRecord.amount), 0)).where(*payment_filters)
            )
            total_payments_collected = Decimal(str(pval or 0))

        items.append(
            ZoneWiseReportItem(
                zone_id=z.id,
                zone_name=z.name,
                partner_count=partner_count,
                order_count=order_count,
                total_order_value=total_order_value,
                payment_count=payment_count,
                total_payments_collected=total_payments_collected,
            )
        )
        total_all_orders += order_count
        total_all_order_value += total_order_value

    # If no specific zone filter, also check for unassigned partners
    if zone_id is None:
        unassigned_partner_ids = db.scalars(
            select(PartnerProfile.user_id).where(PartnerProfile.zone_id.is_(None))
        ).all()
        if unassigned_partner_ids:
            order_filters = [Order.partner_id.in_(unassigned_partner_ids)]
            if parsed_date_from:
                order_filters.append(Order.created_at >= parsed_date_from)
            if parsed_date_to:
                order_filters.append(Order.created_at <= parsed_date_to)

            u_order_count = db.scalar(
                select(func.count(Order.id)).where(*order_filters)
            ) or 0
            u_val = db.scalar(
                select(func.coalesce(func.sum(OrderItem.quantity * OrderItem.unit_price), 0))
                .select_from(OrderItem)
                .join(Order, OrderItem.order_id == Order.id)
                .where(Order.status.in_(["approved_processing", "dispatched", "delivered"]), *order_filters)
            )
            u_total_order_value = Decimal(str(u_val or 0))

            payment_filters = [
                StaffPaymentRecord.partner_id.in_(unassigned_partner_ids),
                StaffPaymentRecord.status == "approved",
            ]
            if parsed_date_from:
                payment_filters.append(StaffPaymentRecord.recorded_at >= parsed_date_from)
            if parsed_date_to:
                payment_filters.append(StaffPaymentRecord.recorded_at <= parsed_date_to)

            u_payment_count = db.scalar(
                select(func.count(StaffPaymentRecord.id)).where(*payment_filters)
            ) or 0
            u_pval = db.scalar(
                select(func.coalesce(func.sum(StaffPaymentRecord.amount), 0)).where(*payment_filters)
            )
            u_total_payments = Decimal(str(u_pval or 0))

            items.append(
                ZoneWiseReportItem(
                    zone_id=None,
                    zone_name="Unassigned Zone",
                    partner_count=len(unassigned_partner_ids),
                    order_count=u_order_count,
                    total_order_value=u_total_order_value,
                    payment_count=u_payment_count,
                    total_payments_collected=u_total_payments,
                )
            )
            total_all_orders += u_order_count
            total_all_order_value += u_total_order_value

    return ZoneWiseReportResponse(
        items=items,
        total_zones=len(items),
        total_orders=total_all_orders,
        total_order_value=total_all_order_value,
    )


# ---------------------------------------------------------------------------
# Area-Wise Report
# ---------------------------------------------------------------------------

@router.get("/reports/area-wise", response_model=AreaWiseReportResponse)
def get_area_wise_report(
    date_from: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    date_to: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    zone_id: Optional[int] = Query(None, description="Filter by Zone ID"),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AreaWiseReportResponse:
    parsed_date_from = _parse_filter_date(date_from, is_end_of_day=False)
    parsed_date_to = _parse_filter_date(date_to, is_end_of_day=True)

    if parsed_date_from and parsed_date_to and parsed_date_from > parsed_date_to:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_from must be earlier than or equal to date_to.",
        )

    # Fetch distinct addresses/areas from partner profiles
    partner_query = select(PartnerProfile)
    if zone_id is not None:
        partner_query = partner_query.where(PartnerProfile.zone_id == zone_id)
    partners = db.scalars(partner_query).all()

    # Group partners by address / area string
    areas_map: dict[str, list[int]] = {}
    for p in partners:
        area_key = (p.business_address or "Unknown Area").strip()
        if not area_key:
            area_key = "Unknown Area"
        areas_map.setdefault(area_key, []).append(p.user_id)

    items: list[AreaWiseReportItem] = []
    for area_name, uids in sorted(areas_map.items()):
        order_filters = [Order.partner_id.in_(uids)]
        if parsed_date_from:
            order_filters.append(Order.created_at >= parsed_date_from)
        if parsed_date_to:
            order_filters.append(Order.created_at <= parsed_date_to)

        order_count = db.scalar(
            select(func.count(Order.id)).where(*order_filters)
        ) or 0

        val = db.scalar(
            select(func.coalesce(func.sum(OrderItem.quantity * OrderItem.unit_price), 0))
            .select_from(OrderItem)
            .join(Order, OrderItem.order_id == Order.id)
            .where(Order.status.in_(["approved_processing", "dispatched", "delivered"]), *order_filters)
        )
        total_order_value = Decimal(str(val or 0))

        items.append(
            AreaWiseReportItem(
                area_name=area_name,
                partner_count=len(uids),
                order_count=order_count,
                total_order_value=total_order_value,
            )
        )

    return AreaWiseReportResponse(items=items, total_areas=len(items))


# ---------------------------------------------------------------------------
# Staff-Wise Report
# ---------------------------------------------------------------------------

@router.get("/reports/staff-wise", response_model=StaffWiseReportResponse)
def get_staff_wise_report(
    date_from: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    date_to: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    staff_id: Optional[int] = Query(None, description="Filter by staff user ID"),
    zone_id: Optional[int] = Query(None, description="Filter by assigned Partner Zone"),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> StaffWiseReportResponse:
    parsed_date_from = _parse_filter_date(date_from, is_end_of_day=False)
    parsed_date_to = _parse_filter_date(date_to, is_end_of_day=True)

    if parsed_date_from and parsed_date_to and parsed_date_from > parsed_date_to:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_from must be earlier than or equal to date_to.",
        )

    staff_query = select(StaffProfile, User).join(User, StaffProfile.user_id == User.id).order_by(User.name.asc())
    if staff_id is not None:
        staff_query = staff_query.where(StaffProfile.user_id == staff_id)
    staff_rows = db.execute(staff_query).all()

    items: list[StaffWiseReportItem] = []
    for sp, u in staff_rows:
        # Active assignments for this staff
        assignment_query = select(StaffPartnerAssignment.partner_id).where(
            StaffPartnerAssignment.staff_id == sp.user_id,
            StaffPartnerAssignment.is_active.is_(True),
        )
        if zone_id is not None:
            assignment_query = assignment_query.where(
                StaffPartnerAssignment.partner_id.in_(
                    select(PartnerProfile.user_id).where(PartnerProfile.zone_id == zone_id)
                )
            )
        assigned_partner_ids = db.scalars(assignment_query).all()

        # Phase 5.A: Staff-wise order queries aggregate using Order.assigned_staff_id == staff_user_id
        order_filters = [Order.assigned_staff_id == sp.user_id]
        if parsed_date_from:
            order_filters.append(Order.created_at >= parsed_date_from)
        if parsed_date_to:
            order_filters.append(Order.created_at <= parsed_date_to)
        if zone_id is not None:
            order_filters.append(
                Order.partner_id.in_(
                    select(PartnerProfile.user_id).where(PartnerProfile.zone_id == zone_id)
                )
            )

        order_count = db.scalar(
            select(func.count(Order.id)).where(*order_filters)
        ) or 0
        val = db.scalar(
            select(func.coalesce(func.sum(OrderItem.quantity * OrderItem.unit_price), 0))
            .select_from(OrderItem)
            .join(Order, OrderItem.order_id == Order.id)
            .where(Order.status.in_(["approved_processing", "dispatched", "delivered"]), *order_filters)
        )
        total_order_value = Decimal(str(val or 0))

        # Payments recorded by this staff
        payment_filters = [
            StaffPaymentRecord.staff_id == sp.user_id,
            StaffPaymentRecord.status == "approved",
        ]
        if parsed_date_from:
            payment_filters.append(StaffPaymentRecord.recorded_at >= parsed_date_from)
        if parsed_date_to:
            payment_filters.append(StaffPaymentRecord.recorded_at <= parsed_date_to)
        if zone_id is not None:
            payment_filters.append(
                StaffPaymentRecord.partner_id.in_(
                    select(PartnerProfile.user_id).where(PartnerProfile.zone_id == zone_id)
                )
            )

        payment_count = db.scalar(
            select(func.count(StaffPaymentRecord.id)).where(*payment_filters)
        ) or 0
        pval = db.scalar(
            select(func.coalesce(func.sum(StaffPaymentRecord.amount), 0)).where(*payment_filters)
        )
        total_payments_collected = Decimal(str(pval or 0))

        items.append(
            StaffWiseReportItem(
                staff_user_id=sp.user_id,
                staff_id=sp.staff_id,
                name=u.name,
                mobile=u.mobile,
                assigned_partner_count=len(assigned_partner_ids),
                order_count=order_count,
                total_order_value=total_order_value,
                payment_count=payment_count,
                total_payments_collected=total_payments_collected,
                attribution_category="assigned",
            )
        )

    # Phase 5.B: Separate unattributed categories (when not filtering by a single staff member)
    if staff_id is None:
        # 1. Unassigned
        u_filters = [Order.staff_attribution_status == "unassigned"]
        if parsed_date_from:
            u_filters.append(Order.created_at >= parsed_date_from)
        if parsed_date_to:
            u_filters.append(Order.created_at <= parsed_date_to)
        if zone_id is not None:
            u_filters.append(
                Order.partner_id.in_(
                    select(PartnerProfile.user_id).where(PartnerProfile.zone_id == zone_id)
                )
            )

        u_order_count = db.scalar(
            select(func.count(Order.id)).where(*u_filters)
        ) or 0
        u_val = db.scalar(
            select(func.coalesce(func.sum(OrderItem.quantity * OrderItem.unit_price), 0))
            .select_from(OrderItem)
            .join(Order, OrderItem.order_id == Order.id)
            .where(Order.status.in_(["approved_processing", "dispatched", "delivered"]), *u_filters)
        )
        items.append(
            StaffWiseReportItem(
                staff_user_id=None,
                staff_id=None,
                name="Unassigned",
                mobile=None,
                assigned_partner_count=0,
                order_count=u_order_count,
                total_order_value=Decimal(str(u_val or 0)),
                payment_count=0,
                total_payments_collected=Decimal("0.00"),
                attribution_category="unassigned",
            )
        )

        # 2. Historically Unattributed
        hu_filters = [Order.staff_attribution_status == "historically_unattributed"]
        if parsed_date_from:
            hu_filters.append(Order.created_at >= parsed_date_from)
        if parsed_date_to:
            hu_filters.append(Order.created_at <= parsed_date_to)
        if zone_id is not None:
            hu_filters.append(
                Order.partner_id.in_(
                    select(PartnerProfile.user_id).where(PartnerProfile.zone_id == zone_id)
                )
            )

        hu_order_count = db.scalar(
            select(func.count(Order.id)).where(*hu_filters)
        ) or 0
        hu_val = db.scalar(
            select(func.coalesce(func.sum(OrderItem.quantity * OrderItem.unit_price), 0))
            .select_from(OrderItem)
            .join(Order, OrderItem.order_id == Order.id)
            .where(Order.status.in_(["approved_processing", "dispatched", "delivered"]), *hu_filters)
        )
        items.append(
            StaffWiseReportItem(
                staff_user_id=None,
                staff_id=None,
                name="Historically Unattributed",
                mobile=None,
                assigned_partner_count=0,
                order_count=hu_order_count,
                total_order_value=Decimal(str(hu_val or 0)),
                payment_count=0,
                total_payments_collected=Decimal("0.00"),
                attribution_category="historically_unattributed",
            )
        )

    return StaffWiseReportResponse(items=items, total_staff=len(staff_rows))


# ---------------------------------------------------------------------------
# Partner-Wise Report
# ---------------------------------------------------------------------------

@router.get("/reports/partner-wise", response_model=PartnerWiseReportResponse)
def get_partner_wise_report(
    date_from: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    date_to: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    partner_id: Optional[int] = Query(None, description="Filter by Partner user ID"),
    zone_id: Optional[int] = Query(None, description="Filter by Zone ID"),
    staff_id: Optional[int] = Query(None, description="Filter by assigned Staff ID"),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PartnerWiseReportResponse:
    parsed_date_from = _parse_filter_date(date_from, is_end_of_day=False)
    parsed_date_to = _parse_filter_date(date_to, is_end_of_day=True)

    if parsed_date_from and parsed_date_to and parsed_date_from > parsed_date_to:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_from must be earlier than or equal to date_to.",
        )

    partner_query = (
        select(PartnerProfile, User, Zone.name.label("zone_name"))
        .join(User, PartnerProfile.user_id == User.id)
        .outerjoin(Zone, PartnerProfile.zone_id == Zone.id)
        .order_by(User.name.asc())
    )

    if partner_id is not None:
        partner_query = partner_query.where(PartnerProfile.user_id == partner_id)
    if zone_id is not None:
        partner_query = partner_query.where(PartnerProfile.zone_id == zone_id)
    if staff_id is not None:
        historical_order_filters = [Order.assigned_staff_id == staff_id]
        if parsed_date_from:
            historical_order_filters.append(Order.created_at >= parsed_date_from)
        if parsed_date_to:
            historical_order_filters.append(Order.created_at <= parsed_date_to)

        order_partner_subquery = (
            select(Order.partner_id)
            .where(*historical_order_filters)
        )

        payment_partner_filters = [
            StaffPaymentRecord.staff_id == staff_id,
            StaffPaymentRecord.status == "approved",
        ]
        if parsed_date_from:
            payment_partner_filters.append(StaffPaymentRecord.recorded_at >= parsed_date_from)
        if parsed_date_to:
            payment_partner_filters.append(StaffPaymentRecord.recorded_at <= parsed_date_to)

        payment_partner_subquery = (
            select(StaffPaymentRecord.partner_id)
            .where(*payment_partner_filters)
        )

        matching_partners_subquery = union(
            order_partner_subquery,
            payment_partner_subquery,
        )
        partner_query = partner_query.where(PartnerProfile.user_id.in_(matching_partners_subquery))

    partner_rows = db.execute(partner_query).all()

    items: list[PartnerWiseReportItem] = []
    for pp, u, zname in partner_rows:
        order_filters = [Order.partner_id == pp.user_id]
        if staff_id is not None:
            order_filters.append(Order.assigned_staff_id == staff_id)
        if parsed_date_from:
            order_filters.append(Order.created_at >= parsed_date_from)
        if parsed_date_to:
            order_filters.append(Order.created_at <= parsed_date_to)

        order_count = db.scalar(
            select(func.count(Order.id)).where(*order_filters)
        ) or 0
        val = db.scalar(
            select(func.coalesce(func.sum(OrderItem.quantity * OrderItem.unit_price), 0))
            .select_from(OrderItem)
            .join(Order, OrderItem.order_id == Order.id)
            .where(Order.status.in_(["approved_processing", "dispatched", "delivered"]), *order_filters)
        )
        total_order_value = Decimal(str(val or 0))

        payment_filters = [
            StaffPaymentRecord.partner_id == pp.user_id,
            StaffPaymentRecord.status == "approved",
        ]
        if staff_id is not None:
            payment_filters.append(StaffPaymentRecord.staff_id == staff_id)
        if parsed_date_from:
            payment_filters.append(StaffPaymentRecord.recorded_at >= parsed_date_from)
        if parsed_date_to:
            payment_filters.append(StaffPaymentRecord.recorded_at <= parsed_date_to)

        payment_count = db.scalar(
            select(func.count(StaffPaymentRecord.id)).where(*payment_filters)
        ) or 0
        pval = db.scalar(
            select(func.coalesce(func.sum(StaffPaymentRecord.amount), 0)).where(*payment_filters)
        )
        total_payments_made = Decimal(str(pval or 0))

        items.append(
            PartnerWiseReportItem(
                partner_user_id=pp.user_id,
                partner_name=u.name,
                business_name=pp.business_name,
                mobile=u.mobile,
                partner_code=pp.partner_code,
                zone_name=zname or "Unassigned",
                order_count=order_count,
                total_order_value=total_order_value,
                payment_count=payment_count,
                total_payments_made=total_payments_made,
            )
        )

    return PartnerWiseReportResponse(items=items, total_partners=len(items))

