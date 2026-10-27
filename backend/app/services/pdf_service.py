from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
import io
from pathlib import Path
from typing import TYPE_CHECKING

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    HRFlowable,
    Image,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

if TYPE_CHECKING:
    from app.models import Order


def _find_logo_path() -> Path | None:
    """Find the Score logo in project assets."""
    possible_paths = [
        Path(__file__).resolve().parent.parent.parent.parent / "assets" / "images" / "app_logo.png",
        Path.cwd() / "assets" / "images" / "app_logo.png",
        Path.cwd().parent / "assets" / "images" / "app_logo.png",
    ]
    for p in possible_paths:
        if p.is_file():
            return p
    return None


class NumberedCanvas:
    """Helper to draw footers on all pages with correct page count."""
    pass


def generate_order_pdf(order: Order) -> bytes:
    """
    Generates a professional, multi-page capable PDF document for an order.
    The order and its item snapshots from the database serve as the source of truth.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        leftMargin=36,
        rightMargin=36,
        topMargin=36,
        bottomMargin=45,
    )

    styles = getSampleStyleSheet()

    # Custom styles
    primary_color = colors.HexColor("#083FA5")
    dark_neutral = colors.HexColor("#1A202C")
    light_blue = colors.HexColor("#EBF5FF")
    border_blue = colors.HexColor("#CBEBFF")
    muted_text = colors.HexColor("#4A5568")

    title_style = ParagraphStyle(
        "DocTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=20,
        leading=24,
        textColor=primary_color,
    )

    header_label_style = ParagraphStyle(
        "HeaderLabel",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=10,
        leading=14,
        textColor=primary_color,
    )

    header_value_style = ParagraphStyle(
        "HeaderValue",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=10,
        leading=14,
        textColor=dark_neutral,
    )

    table_header_style = ParagraphStyle(
        "TableHeader",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9,
        leading=12,
        textColor=primary_color,
    )

    table_cell_style = ParagraphStyle(
        "TableCell",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        leading=12,
        textColor=dark_neutral,
    )

    table_cell_right_style = ParagraphStyle(
        "TableCellRight",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        leading=12,
        textColor=dark_neutral,
        alignment=2,  # Right aligned
    )

    total_label_style = ParagraphStyle(
        "TotalLabel",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=10,
        leading=14,
        textColor=primary_color,
        alignment=2,
    )

    total_value_style = ParagraphStyle(
        "TotalValue",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=11,
        leading=14,
        textColor=primary_color,
        alignment=2,
    )

    story = []

    # 1. Header section with Logo and Document Title
    logo_path = _find_logo_path()
    logo_widget = None
    if logo_path and logo_path.is_file():
        try:
            logo_widget = Image(str(logo_path), width=1.5 * inch, height=0.55 * inch)
        except Exception:
            logo_widget = Paragraph("<b>Score</b>", title_style)
    else:
        logo_widget = Paragraph("<b>Score</b>", title_style)

    header_meta = [
        [
            logo_widget,
            Paragraph(
                f"<b>ORDER INVOICE / SUMMARY</b><br/>"
                f"<font size=9 color='#4A5568'>Score Mobility Platform</font>",
                ParagraphStyle("InvHead", parent=title_style, alignment=2, fontSize=14, leading=18),
            ),
        ]
    ]

    header_table = Table(header_meta, colWidths=[200, 340])
    header_table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 0),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    story.append(header_table)
    story.append(HRFlowable(width="100%", thickness=1.5, color=primary_color, spaceBefore=4, spaceAfter=12))

    # 2. Order Metadata & Partner Details Grid
    partner = order.partner
    partner_profile = getattr(partner, "partner_profile", None) if partner else None

    partner_name = partner.name if partner else f"Partner #{order.partner_id}"
    business_name = partner_profile.business_name if partner_profile else "N/A"
    partner_mobile = partner.mobile if partner else "N/A"
    partner_address = partner_profile.business_address if partner_profile else "N/A"
    partner_code = partner_profile.partner_code if (partner_profile and partner_profile.partner_code) else "N/A"

    order_date_str = (
        order.created_at.strftime("%d %b %Y, %I:%M %p")
        if order.created_at
        else datetime.now(timezone.utc).strftime("%d %b %Y, %I:%M %p")
    )
    status_display = order.status.replace("_", " ").upper()

    order_meta_data = [
        [
            Paragraph("<b>Order Number:</b>", header_label_style),
            Paragraph(order.order_number, header_value_style),
            Paragraph("<b>Partner Code:</b>", header_label_style),
            Paragraph(partner_code, header_value_style),
        ],
        [
            Paragraph("<b>Order Date:</b>", header_label_style),
            Paragraph(order_date_str, header_value_style),
            Paragraph("<b>Business Name:</b>", header_label_style),
            Paragraph(business_name, header_value_style),
        ],
        [
            Paragraph("<b>Order Status:</b>", header_label_style),
            Paragraph(f"<b><font color='#083FA5'>{status_display}</font></b>", header_value_style),
            Paragraph("<b>Contact Person:</b>", header_label_style),
            Paragraph(partner_name, header_value_style),
        ],
        [
            Paragraph("<b>Notes:</b>", header_label_style),
            Paragraph(order.notes or "None", header_value_style),
            Paragraph("<b>Mobile:</b>", header_label_style),
            Paragraph(partner_mobile, header_value_style),
        ],
        [
            "",
            "",
            Paragraph("<b>Address:</b>", header_label_style),
            Paragraph(partner_address.replace("\n", ", "), header_value_style),
        ],
    ]

    meta_table = Table(order_meta_data, colWidths=[90, 180, 100, 170])
    meta_table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
                ("BOX", (0, 0), (-1, -1), 0.5, border_blue),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#EDF2F7")),
            ]
        )
    )
    story.append(meta_table)
    story.append(Spacer(1, 14))

    # 3. Items Table
    items = order.items or []
    items_data = [
        [
            Paragraph("<b>#</b>", table_header_style),
            Paragraph("<b>SKU / Code</b>", table_header_style),
            Paragraph("<b>Product Name</b>", table_header_style),
            Paragraph("<b>Vehicle</b>", table_header_style),
            Paragraph("<b>Qty</b>", table_header_style),
            Paragraph("<b>Unit Price</b>", table_header_style),
            Paragraph("<b>Line Total</b>", table_header_style),
        ]
    ]

    total_qty = 0
    grand_total = Decimal("0.00")

    for idx, item in enumerate(items, start=1):
        product = item.product
        sku = product.product_code if product else f"PRD-{item.product_id}"
        prod_name = product.name if product else f"Product #{item.product_id}"
        vtype = product.vehicle_type if product else "N/A"
        qty = item.quantity
        unit_price = Decimal(str(item.unit_price))
        line_total = qty * unit_price

        total_qty += qty
        grand_total += line_total

        items_data.append(
            [
                Paragraph(str(idx), table_cell_style),
                Paragraph(sku, table_cell_style),
                Paragraph(prod_name, table_cell_style),
                Paragraph(vtype, table_cell_style),
                Paragraph(str(qty), table_cell_style),
                Paragraph(f"Rs. {unit_price:,.2f}", table_cell_right_style),
                Paragraph(f"Rs. {line_total:,.2f}", table_cell_right_style),
            ]
        )

    # Grand total summary rows
    items_data.append(
        [
            "",
            "",
            Paragraph("<b>Total Items:</b>", total_label_style),
            Paragraph(f"<b>{len(items)}</b>", table_cell_style),
            Paragraph(f"<b>{total_qty}</b>", table_cell_style),
            Paragraph("<b>Grand Total:</b>", total_label_style),
            Paragraph(f"<b>Rs. {grand_total:,.2f}</b>", total_value_style),
        ]
    )

    col_widths = [25, 95, 175, 65, 35, 70, 75]
    items_table = Table(items_data, colWidths=col_widths, repeatRows=1)
    items_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), light_blue),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("BOX", (0, 0), (-1, -1), 0.5, border_blue),
                ("INNERGRID", (0, 0), (-1, -2), 0.5, colors.HexColor("#E2E8F0")),
                # Total row styling
                ("BACKGROUND", (0, -1), (-1, -1), colors.HexColor("#F1F5F9")),
                ("LINEABOVE", (0, -1), (-1, -1), 1.2, primary_color),
            ]
        )
    )
    story.append(items_table)
    story.append(Spacer(1, 16))

    # 4. Approval and Workflow Notice
    notice_text = (
        "<b>Important Notice:</b> This order has been submitted and is currently in "
        f"<b>{status_display}</b> status. Newly placed orders are subject to Staff and Admin "
        "approval before dispatch. No payment or stock transfer is finalized until confirmed by authorized personnel."
    )
    notice_p = Paragraph(
        notice_text,
        ParagraphStyle(
            "NoticeStyle",
            parent=styles["Normal"],
            fontName="Helvetica",
            fontSize=8.5,
            leading=12,
            textColor=muted_text,
        ),
    )
    notice_table = Table([[notice_p]], colWidths=[540])
    notice_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#FEF3C7")),
                ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#F59E0B")),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
            ]
        )
    )
    story.append(notice_table)

    # 5. Footer generator callback
    now_utc = datetime.now(timezone.utc).strftime("%d %b %Y, %I:%M %p UTC")

    def _draw_footer(canvas, doc):
        canvas.saveState()
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(colors.HexColor("#718096"))
        footer_text = f"Document Generated: {now_utc} | Score App Order Reference: {order.order_number}"
        canvas.drawString(36, 25, footer_text)
        canvas.drawRightString(letter[0] - 36, 25, f"Page {canvas._pageNumber}")
        canvas.setStrokeColor(border_blue)
        canvas.setLineWidth(0.5)
        canvas.line(36, 35, letter[0] - 36, 35)
        canvas.restoreState()

    doc.build(story, onFirstPage=_draw_footer, onLaterPages=_draw_footer)
    return buffer.getvalue()
