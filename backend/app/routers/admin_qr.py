from __future__ import annotations

import csv
from datetime import datetime, timezone
import io
import logging
import secrets
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from fastapi.responses import StreamingResponse
import openpyxl
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from app.core.security import require_admin
from app.db.session import get_db
from app.models import PointsRule, Product, QrBatch, QrCode, User
from app.schemas.admin_qr import (
    ProductQrLabelItem,
    ProductQrLabelListResponse,
    ProductQrLabelRequest,
    QrBatchCreate,
    QrBatchListResponse,
    QrBatchResponse,
    QrCodeListResponse,
    QrCodeResponse,
    QrCodeStatusUpdate,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/admin/qr", tags=["admin_qr"])


def _to_code_response(code: QrCode) -> QrCodeResponse:
    return QrCodeResponse(
        id=code.id,
        batch_id=code.batch_id,
        qr_type=code.qr_type,
        token=code.token,
        code_data=code.code_data,
        points_awarded=code.points_awarded,
        product_id=code.product_id,
        product_name=code.product.name if code.product else None,
        target_user_id=code.target_user_id,
        target_user_name=code.target_user.name if code.target_user else None,
        status=code.status,
        redeemed_by=code.redeemed_by,
        redeemed_at=code.redeemed_at,
        expires_at=code.expires_at,
        created_at=code.created_at,
    )


def _to_batch_response(batch: QrBatch, db: Session) -> QrBatchResponse:
    counts_query = (
        select(
            func.count(QrCode.id).filter(QrCode.status == "active").label("active_count"),
            func.count(QrCode.id).filter(QrCode.status == "redeemed").label("redeemed_count"),
            func.count(QrCode.id).filter(QrCode.status == "voided").label("voided_count"),
        )
        .where(QrCode.batch_id == batch.id)
    )
    counts = db.execute(counts_query).one()

    return QrBatchResponse(
        id=batch.id,
        batch_number=batch.batch_number,
        qr_type=batch.qr_type,
        description=batch.description,
        points_rule_id=batch.points_rule_id,
        points_rule_name=batch.points_rule.rule_name if batch.points_rule else None,
        product_id=batch.product_id,
        product_name=batch.product.name if batch.product else None,
        target_user_id=batch.target_user_id,
        target_user_name=batch.target_user.name if batch.target_user else None,
        quantity=batch.quantity,
        status=batch.status,
        active_count=counts.active_count or 0,
        redeemed_count=counts.redeemed_count or 0,
        voided_count=counts.voided_count or 0,
        created_by=batch.created_by,
        created_by_name=batch.creator.name if batch.creator else None,
        created_at=batch.created_at,
    )


# -----------------------------------------------------------------------------
# Batch Management
# -----------------------------------------------------------------------------


@router.post(
    "/batches",
    response_model=QrBatchResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new batch and generate QR codes",
)
def create_qr_batch(
    payload: QrBatchCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> QrBatchResponse:
    # 1. Validate Product if specified
    product = None
    if payload.product_id:
        product = db.get(Product, payload.product_id)
        if not product:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Product with id {payload.product_id} not found",
            )

    # 2. Validate Target User if specified
    target_user = None
    if payload.target_user_id:
        target_user = db.get(User, payload.target_user_id)
        if not target_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Target user with id {payload.target_user_id} not found",
            )
        if payload.qr_type == "partner" and target_user.role != "partner":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Target user must have 'partner' role for partner QR codes",
            )
        if payload.qr_type == "staff" and target_user.role != "staff":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Target user must have 'staff' role for staff QR codes",
            )

    # 3. Validate Points Rule if specified
    points_rule = None
    points_awarded = None
    if payload.points_rule_id:
        points_rule = db.get(PointsRule, payload.points_rule_id)
        if not points_rule:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Points rule with id {payload.points_rule_id} not found",
            )
        if not points_rule.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Points rule '{points_rule.rule_name}' is inactive",
            )
        points_awarded = points_rule.points_awarded

    # 4. Generate unique Batch Number
    date_str = datetime.now(timezone.utc).strftime("%Y%m%d")
    batch_number = f"BATCH-{date_str}-{secrets.token_hex(3).upper()}"
    while db.execute(select(QrBatch).where(QrBatch.batch_number == batch_number)).scalar_one_or_none():
        batch_number = f"BATCH-{date_str}-{secrets.token_hex(3).upper()}"

    # 5. Create Batch
    batch = QrBatch(
        batch_number=batch_number,
        qr_type=payload.qr_type,
        description=payload.description,
        points_rule_id=payload.points_rule_id,
        product_id=payload.product_id,
        target_user_id=payload.target_user_id,
        quantity=payload.quantity,
        status="completed",
        created_by=admin.id,
    )
    db.add(batch)
    db.flush()

    # 6. Generate individual QR codes with cryptographically unique tokens
    for _ in range(payload.quantity):
        token = secrets.token_hex(16).upper()  # 32 characters
        # Ensure uniqueness
        while db.execute(select(QrCode).where(QrCode.token == token)).scalar_one_or_none():
            token = secrets.token_hex(16).upper()

        # Format URL / payload
        code_data = f"score://qr/v1?token={token}&type={payload.qr_type}"

        qr_code = QrCode(
            batch_id=batch.id,
            qr_type=payload.qr_type,
            token=token,
            code_data=code_data,
            points_awarded=points_awarded,
            product_id=payload.product_id,
            target_user_id=payload.target_user_id,
            status="active",
        )
        db.add(qr_code)

    db.commit()
    db.refresh(batch)

    logger.info(
        "Admin user %s created QR batch %s with %d codes (type: %s)",
        admin.id,
        batch.batch_number,
        payload.quantity,
        payload.qr_type,
    )

    return _to_batch_response(batch, db)


@router.get(
    "/batches",
    response_model=QrBatchListResponse,
    summary="List generated QR batches with filters",
)
def list_qr_batches(
    qr_type: Optional[str] = Query(None, description="Filter by QR type (product, invoice, staff, partner)"),
    status: Optional[str] = Query(None, description="Filter by batch status (completed, active, cancelled)"),
    search: Optional[str] = Query(None, description="Search by batch number or description"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> QrBatchListResponse:
    query = select(QrBatch).options(
        selectinload(QrBatch.points_rule),
        selectinload(QrBatch.product),
        selectinload(QrBatch.target_user),
        selectinload(QrBatch.creator),
    )

    if qr_type:
        query = query.where(QrBatch.qr_type == qr_type)
    if status:
        query = query.where(QrBatch.status == status)
    if search:
        search_filter = f"%{search.strip()}%"
        query = query.where(
            QrBatch.batch_number.ilike(search_filter) | QrBatch.description.ilike(search_filter)
        )

    # Count total
    count_query = select(func.count(QrBatch.id))
    if qr_type:
        count_query = count_query.where(QrBatch.qr_type == qr_type)
    if status:
        count_query = count_query.where(QrBatch.status == status)
    if search:
        search_filter = f"%{search.strip()}%"
        count_query = count_query.where(
            QrBatch.batch_number.ilike(search_filter) | QrBatch.description.ilike(search_filter)
        )
    total = db.scalar(count_query) or 0

    # Order and paginate
    offset = (page - 1) * page_size
    batches = db.execute(
        query.order_by(QrBatch.created_at.desc()).offset(offset).limit(page_size)
    ).scalars().all()

    items = [_to_batch_response(b, db) for b in batches]
    return QrBatchListResponse(items=items, total=total)


@router.get(
    "/batches/{batch_id}",
    response_model=QrBatchResponse,
    summary="Get QR batch details",
)
def get_qr_batch(
    batch_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> QrBatchResponse:
    batch = db.execute(
        select(QrBatch)
        .options(
            selectinload(QrBatch.points_rule),
            selectinload(QrBatch.product),
            selectinload(QrBatch.target_user),
            selectinload(QrBatch.creator),
        )
        .where(QrBatch.id == batch_id)
    ).scalar_one_or_none()

    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"QR Batch with id {batch_id} not found",
        )

    return _to_batch_response(batch, db)


@router.get(
    "/batches/{batch_id}/codes",
    response_model=QrCodeListResponse,
    summary="List individual QR codes in a batch",
)
def list_batch_codes(
    batch_id: int,
    status: Optional[str] = Query(None, description="Filter by status (active, redeemed, voided, expired)"),
    search: Optional[str] = Query(None, description="Search by token"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> QrCodeListResponse:
    batch = db.get(QrBatch, batch_id)
    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"QR Batch with id {batch_id} not found",
        )

    query = (
        select(QrCode)
        .options(
            selectinload(QrCode.product),
            selectinload(QrCode.target_user),
        )
        .where(QrCode.batch_id == batch_id)
    )

    if status:
        query = query.where(QrCode.status == status)
    if search:
        query = query.where(QrCode.token.ilike(f"%{search.strip()}%"))

    count_query = select(func.count(QrCode.id)).where(QrCode.batch_id == batch_id)
    if status:
        count_query = count_query.where(QrCode.status == status)
    if search:
        count_query = count_query.where(QrCode.token.ilike(f"%{search.strip()}%"))

    total = db.scalar(count_query) or 0
    offset = (page - 1) * page_size
    codes = db.execute(
        query.order_by(QrCode.id.asc()).offset(offset).limit(page_size)
    ).scalars().all()

    items = [_to_code_response(c) for c in codes]
    return QrCodeListResponse(items=items, total=total)


# -----------------------------------------------------------------------------
# Excel & CSV Exports
# -----------------------------------------------------------------------------


@router.get(
    "/batches/{batch_id}/export/excel",
    summary="Export QR batch to styled Microsoft Excel (.xlsx) file",
)
def export_batch_excel(
    batch_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> StreamingResponse:
    batch = db.execute(
        select(QrBatch)
        .options(
            selectinload(QrBatch.product),
            selectinload(QrBatch.target_user),
        )
        .where(QrBatch.id == batch_id)
    ).scalar_one_or_none()

    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"QR Batch with id {batch_id} not found",
        )

    codes = db.execute(
        select(QrCode)
        .options(
            selectinload(QrCode.product),
            selectinload(QrCode.target_user),
        )
        .where(QrCode.batch_id == batch_id)
        .order_by(QrCode.id.asc())
    ).scalars().all()

    # Create Excel Workbook
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "QR Codes"

    # Score styling
    header_fill = PatternFill(start_color="002766", end_color="002766", fill_type="solid")
    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    center_align = Alignment(horizontal="center", vertical="center")
    left_align = Alignment(horizontal="left", vertical="center")
    thin_border = Border(
        left=Side(style="thin", color="E0E0E0"),
        right=Side(style="thin", color="E0E0E0"),
        top=Side(style="thin", color="E0E0E0"),
        bottom=Side(style="thin", color="E0E0E0"),
    )

    headers = [
        "S.No",
        "Batch ID",
        "Batch Number",
        "QR ID",
        "QR Token",
        "QR Code Data (Payload)",
        "QR Type",
        "Points Awarded",
        "Target Item / User",
        "Status",
        "Created Date (UTC)",
        "Expiry Date",
    ]

    ws.append(headers)
    for col_idx in range(1, len(headers) + 1):
        cell = ws.cell(row=1, column=col_idx)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = center_align

    for idx, code in enumerate(codes, start=1):
        target_name = "None"
        if code.product:
            target_name = f"{code.product.name} ({code.product.product_code})"
        elif code.target_user:
            target_name = f"{code.target_user.name} ({code.target_user.role.upper()})"

        created_str = code.created_at.strftime("%Y-%m-%d %H:%M:%S") if code.created_at else ""
        expires_str = code.expires_at.strftime("%Y-%m-%d %H:%M:%S") if code.expires_at else "Never"

        row = [
            idx,
            batch.id,
            batch.batch_number,
            code.id,
            code.token,
            code.code_data,
            code.qr_type.upper(),
            code.points_awarded or 0,
            target_name,
            code.status.upper(),
            created_str,
            expires_str,
        ]
        ws.append(row)

        row_idx = idx + 1
        for col_idx in range(1, len(row) + 1):
            cell = ws.cell(row=row_idx, column=col_idx)
            cell.border = thin_border
            if col_idx in (1, 2, 4, 7, 8, 10, 11, 12):
                cell.alignment = center_align
            else:
                cell.alignment = left_align

    # Auto-adjust column widths
    for col in ws.columns:
        max_len = max(len(str(cell.value or "")) for cell in col)
        col_letter = get_column_letter(col[0].column)
        ws.column_dimensions[col_letter].width = max(max_len + 3, 12)

    output = io.BytesIO()
    wb.save(output)
    output.seek(0)

    filename = f"{batch.batch_number}_qr_codes.xlsx"
    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get(
    "/batches/{batch_id}/export/csv",
    summary="Export QR batch to CSV file",
)
def export_batch_csv(
    batch_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> Response:
    batch = db.execute(
        select(QrBatch)
        .options(
            selectinload(QrBatch.product),
            selectinload(QrBatch.target_user),
        )
        .where(QrBatch.id == batch_id)
    ).scalar_one_or_none()

    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"QR Batch with id {batch_id} not found",
        )

    codes = db.execute(
        select(QrCode)
        .options(
            selectinload(QrCode.product),
            selectinload(QrCode.target_user),
        )
        .where(QrCode.batch_id == batch_id)
        .order_by(QrCode.id.asc())
    ).scalars().all()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "S.No",
        "Batch Number",
        "QR Token",
        "QR Code Data",
        "Category",
        "Points Awarded",
        "Target Item / User",
        "Status",
        "Created At",
        "Expires At",
    ])

    for idx, code in enumerate(codes, start=1):
        target_name = "None"
        if code.product:
            target_name = f"{code.product.name} ({code.product.product_code})"
        elif code.target_user:
            target_name = f"{code.target_user.name} ({code.target_user.role})"

        writer.writerow([
            idx,
            batch.batch_number,
            code.token,
            code.code_data,
            code.qr_type,
            code.points_awarded or 0,
            target_name,
            code.status,
            code.created_at.isoformat() if code.created_at else "",
            code.expires_at.isoformat() if code.expires_at else "",
        ])

    filename = f"{batch.batch_number}_qr_codes.csv"
    return Response(
        content=output.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


# -----------------------------------------------------------------------------
# Individual QR Code Actions
# -----------------------------------------------------------------------------


@router.patch(
    "/codes/{code_id}/status",
    response_model=QrCodeResponse,
    summary="Update status of an individual QR code (void or activate)",
)
@router.post(
    "/codes/{code_id}/status",
    response_model=QrCodeResponse,
    summary="Update status fallback for restricted HTTP environments",
)
def update_qr_code_status(
    code_id: int,
    payload: QrCodeStatusUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> QrCodeResponse:
    code = db.execute(
        select(QrCode)
        .options(
            selectinload(QrCode.product),
            selectinload(QrCode.target_user),
        )
        .where(QrCode.id == code_id)
    ).scalar_one_or_none()

    if not code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"QR Code with id {code_id} not found",
        )

    if code.status == "redeemed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot alter status of an already redeemed QR code",
        )

    code.status = payload.status
    db.commit()
    db.refresh(code)

    logger.info("Admin %s updated QR code %s status to %s", admin.id, code.id, payload.status)
    return _to_code_response(code)


# -----------------------------------------------------------------------------
# Product QR Number Printing (Feature H1)
# -----------------------------------------------------------------------------


def _get_or_create_product_labels(
    product_ids: list[int],
    db: Session,
    admin: User,
) -> list[ProductQrLabelItem]:
    """Retrieve existing unique QR numbers for the given products, or generate them

    preserving the existing generation mechanism and uniqueness.
    Never replaces or changes QR numbers already assigned to products.
    """
    products = (
        db.execute(
            select(Product)
            .where(Product.id.in_(product_ids))
            .order_by(Product.name.asc())
        )
        .scalars()
        .all()
    )

    if not products:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No matching products found for the specified IDs",
        )

    labels: list[ProductQrLabelItem] = []
    default_batch: Optional[QrBatch] = None

    for product in products:
        # 1. Check for existing active product QR code
        existing_code = (
            db.execute(
                select(QrCode)
                .where(
                    QrCode.product_id == product.id,
                    QrCode.qr_type == "product",
                    QrCode.status == "active",
                )
                .order_by(QrCode.id.desc())
            )
            .scalars()
            .first()
        )

        if existing_code:
            qr_number = existing_code.token
        else:
            # 2. Generate a new unique QR number using the existing token mechanism
            if default_batch is None:
                date_str = datetime.now(timezone.utc).strftime("%Y%m%d")
                batch_number = f"BATCH-PROD-{date_str}-{secrets.token_hex(3).upper()}"
                while db.execute(
                    select(QrBatch).where(QrBatch.batch_number == batch_number)
                ).scalar_one_or_none():
                    batch_number = f"BATCH-PROD-{date_str}-{secrets.token_hex(3).upper()}"

                default_batch = QrBatch(
                    batch_number=batch_number,
                    qr_type="product",
                    description="Auto-generated batch for product QR labels",
                    quantity=1,
                    status="completed",
                    created_by=admin.id,
                )
                db.add(default_batch)
                db.flush()

            token = secrets.token_hex(16).upper()  # 32 characters
            while db.execute(
                select(QrCode).where(QrCode.token == token)
            ).scalar_one_or_none():
                token = secrets.token_hex(16).upper()

            code_data = f"score://qr/v1?token={token}&type=product"
            new_code = QrCode(
                batch_id=default_batch.id,
                qr_type="product",
                token=token,
                code_data=code_data,
                points_awarded=None,
                product_id=product.id,
                status="active",
            )
            db.add(new_code)
            db.flush()
            qr_number = token

        labels.append(
            ProductQrLabelItem(
                product_id=product.id,
                product_name=product.name,
                product_code=product.product_code,
                qr_number=qr_number,
            )
        )

    db.commit()
    return labels


def generate_product_qr_labels_pdf(labels: list[ProductQrLabelItem]) -> io.BytesIO:
    """Generate a clean, readable label layout PDF for physical product labeling.

    NO QR images or graphics are generated. Only the unique QR identification number,
    product name, and product code are rendered.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36,
    )
    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        "DocTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=18,
        leading=22,
        textColor=colors.HexColor("#1E293B"),
        alignment=1,  # Center
    )
    subtitle_style = ParagraphStyle(
        "DocSubtitle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=10,
        leading=14,
        textColor=colors.HexColor("#64748B"),
        alignment=1,
    )
    card_title_style = ParagraphStyle(
        "CardTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=12,
        leading=15,
        textColor=colors.HexColor("#0F172A"),
    )
    card_meta_style = ParagraphStyle(
        "CardMeta",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9,
        leading=12,
        textColor=colors.HexColor("#475569"),
    )
    card_qr_title_style = ParagraphStyle(
        "CardQrTitle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8,
        leading=10,
        textColor=colors.HexColor("#64748B"),
    )
    card_qr_style = ParagraphStyle(
        "CardQr",
        parent=styles["Normal"],
        fontName="Courier-Bold",
        fontSize=11,
        leading=14,
        textColor=colors.HexColor("#1E40AF"),
    )

    story = []
    story.append(Paragraph("SCORE APP — PRODUCT QR LABELS", title_style))
    story.append(Paragraph("Physical Identification Labels (Text Format)", subtitle_style))
    story.append(Spacer(1, 16))

    # Grid of 2 label cards per row
    rows_data = []
    current_row = []

    for item in labels:
        card_content = [
            [Paragraph(f"<b>{item.product_name}</b>", card_title_style)],
            [Paragraph(f"SKU / CODE: <b>{item.product_code}</b>", card_meta_style)],
            [Paragraph("UNIQUE QR IDENTIFICATION NUMBER:", card_qr_title_style)],
            [Paragraph(f"<b>{item.qr_number}</b>", card_qr_style)],
        ]
        card_table = Table(card_content, colWidths=[250])
        card_table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
                    ("BOX", (0, 0), (-1, -1), 1.5, colors.HexColor("#CBD5E1")),
                    ("TOPPADDING", (0, 0), (-1, -1), 8),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                    ("LEFTPADDING", (0, 0), (-1, -1), 12),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 12),
                    ("LINEBELOW", (0, 1), (0, 1), 0.5, colors.HexColor("#E2E8F0")),
                ]
            )
        )

        current_row.append(card_table)
        if len(current_row) == 2:
            rows_data.append(current_row)
            current_row = []

    if current_row:
        # Pad with empty cell if odd number of cards
        current_row.append("")
        rows_data.append(current_row)

    if rows_data:
        layout_table = Table(rows_data, colWidths=[265, 265])
        layout_table.setStyle(
            TableStyle(
                [
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("TOPPADDING", (0, 0), (-1, -1), 8),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                    ("LEFTPADDING", (0, 0), (-1, -1), 4),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ]
            )
        )
        story.append(layout_table)

    doc.build(story)
    buffer.seek(0)
    return buffer


@router.post(
    "/products/labels",
    response_model=ProductQrLabelListResponse,
    summary="Get or retrieve existing product QR identification numbers for selected products",
)
def get_product_qr_labels(
    payload: ProductQrLabelRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> ProductQrLabelListResponse:
    labels = _get_or_create_product_labels(payload.product_ids, db, admin)
    return ProductQrLabelListResponse(items=labels, total=len(labels))


@router.post(
    "/products/labels/pdf",
    summary="Download printable PDF of product QR identification numbers (no QR images)",
)
def download_product_qr_labels_pdf(
    payload: ProductQrLabelRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    labels = _get_or_create_product_labels(payload.product_ids, db, admin)
    pdf_buffer = generate_product_qr_labels_pdf(labels)

    filename = f"product_qr_labels_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.pdf"
    return StreamingResponse(
        pdf_buffer,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get(
    "/products/labels/pdf",
    summary="Download printable PDF via GET query params (comma-separated product_ids)",
)
def download_product_qr_labels_pdf_get(
    product_ids: str = Query(..., description="Comma-separated product IDs, e.g. 1,2,3"),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    try:
        parsed_ids = [int(p.strip()) for p in product_ids.split(",") if p.strip()]
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid product_ids format. Must be comma-separated integers.",
        )
    if not parsed_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="product_ids cannot be empty",
        )

    labels = _get_or_create_product_labels(parsed_ids, db, admin)
    pdf_buffer = generate_product_qr_labels_pdf(labels)

    filename = f"product_qr_labels_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.pdf"
    return StreamingResponse(
        pdf_buffer,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
