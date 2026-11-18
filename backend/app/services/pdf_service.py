from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
import io
from pathlib import Path
import re
from typing import TYPE_CHECKING, Any
from xml.sax.saxutils import escape as _sax_escape
from zoneinfo import ZoneInfo

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    HRFlowable,
    Image,
    KeepTogether,
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


def escape_pdf_text(value: Any) -> str:
    """
    Safely escapes dynamic user-controlled text for insertion into ReportLab Paragraph XML markup.
    Escapes &, <, >, ", and ' while safely handling None, numbers, and Unicode strings.
    """
    if value is None:
        return ""
    text = str(value)
    return _sax_escape(text, {'"': "&quot;", "'": "&apos;"})


# Comprehensive list of Indian States and Union Territories (and common abbreviations)
# These must NEVER be identified as cities.
INDIAN_STATES_AND_UTS: set[str] = {
    "andhra pradesh", "ap",
    "arunachal pradesh", "ar",
    "assam", "as",
    "bihar", "br",
    "chhattisgarh", "chattisgarh", "cg",
    "goa", "ga",
    "gujarat", "gj",
    "haryana", "hr",
    "himachal pradesh", "hp",
    "jharkhand", "jh",
    "karnataka", "ka",
    "kerala", "kl",
    "madhya pradesh", "mp",
    "maharashtra", "mh",
    "manipur", "mn",
    "meghalaya", "ml",
    "mizoram", "mz",
    "nagaland", "nl",
    "odisha", "orissa", "od", "or",
    "punjab", "pb",
    "rajasthan", "rj",
    "sikkim", "sk",
    "tamil nadu", "tn",
    "telangana", "ts", "tg",
    "tripura", "tr",
    "uttar pradesh", "up",
    "uttarakhand", "uttaranchal", "uk", "ua",
    "west bengal", "wb",
    "andaman and nicobar islands", "andaman & nicobar", "an",
    "dadra and nagar haveli and daman and diu", "dadra & nagar haveli", "daman & diu", "dn", "dd",
    "jammu and kashmir", "jammu & kashmir", "j&k", "jk",
    "ladakh", "la",
    "lakshadweep", "ld",
    "puducherry", "pondicherry", "py",
}

COUNTRIES: set[str] = {"india", "bharat", "republic of india", "in", "ind"}

# Regex matching valid 6-digit Indian PIN codes with optional prefix/dashes
# Uses explicit Unicode escapes for dashes (\u2010 to \u2015, \u2212) to avoid malformed ranges
_PIN_REGEX = re.compile(
    r"(?:(?:\bPIN(?:\s*CODE)?\b\s*[:\s\-\u2010\u2012\u2013\u2014\u2015\u2212]*)?|[\-\u2010\u2012\u2013\u2014\u2015\u2212\s]+)\b[1-9]\d{2}\s?\d{3}\b",
    flags=re.IGNORECASE,
)

# Recognized Indian cities mapped to standard display name
KNOWN_INDIAN_CITIES: dict[str, str] = {
    "ahmedabad": "Ahmedabad",
    "pune": "Pune",
    "mumbai": "Mumbai",
    "new delhi": "New Delhi",
    "delhi": "Delhi",
    "bengaluru": "Bengaluru",
    "bangalore": "Bengaluru",
    "chennai": "Chennai",
    "madras": "Chennai",
    "kolkata": "Kolkata",
    "calcutta": "Kolkata",
    "hyderabad": "Hyderabad",
    "secunderabad": "Secunderabad",
    "surat": "Surat",
    "jaipur": "Jaipur",
    "lucknow": "Lucknow",
    "kanpur": "Kanpur",
    "nagpur": "Nagpur",
    "indore": "Indore",
    "thane": "Thane",
    "bhopal": "Bhopal",
    "visakhapatnam": "Visakhapatnam",
    "vizag": "Visakhapatnam",
    "patna": "Patna",
    "vadodara": "Vadodara",
    "baroda": "Vadodara",
    "ghaziabad": "Ghaziabad",
    "ludhiana": "Ludhiana",
    "agra": "Agra",
    "nashik": "Nashik",
    "nasik": "Nashik",
    "faridabad": "Faridabad",
    "meerut": "Meerut",
    "rajkot": "Rajkot",
    "varanasi": "Varanasi",
    "srinagar": "Srinagar",
    "aurangabad": "Aurangabad",
    "chhatrapati sambhajinagar": "Chhatrapati Sambhajinagar",
    "dhanbad": "Dhanbad",
    "amritsar": "Amritsar",
    "navi mumbai": "Navi Mumbai",
    "allahabad": "Prayagraj",
    "prayagraj": "Prayagraj",
    "ranchi": "Ranchi",
    "howrah": "Howrah",
    "coimbatore": "Coimbatore",
    "jabalpur": "Jabalpur",
    "gwalior": "Gwalior",
    "vijayawada": "Vijayawada",
    "jodhpur": "Jodhpur",
    "madurai": "Madurai",
    "raipur": "Raipur",
    "kota": "Kota",
    "guwahati": "Guwahati",
    "chandigarh": "Chandigarh",
    "solapur": "Solapur",
    "hubli": "Hubli",
    "hubballi": "Hubli",
    "dharwad": "Dharwad",
    "mysore": "Mysore",
    "mysuru": "Mysuru",
    "gurgaon": "Gurgaon",
    "gurugram": "Gurugram",
    "noida": "Noida",
    "greater noida": "Greater Noida",
    "jalandhar": "Jalandhar",
    "bhubaneswar": "Bhubaneswar",
    "salem": "Salem",
    "warangal": "Warangal",
    "thiruvananthapuram": "Thiruvananthapuram",
    "trivandrum": "Thiruvananthapuram",
    "kochi": "Kochi",
    "cochin": "Kochi",
    "kozhikode": "Kozhikode",
    "calicut": "Kozhikode",
    "kolhapur": "Kolhapur",
    "sangli": "Sangli",
    "satara": "Satara",
    "jalgaon": "Jalgaon",
    "amravati": "Amravati",
    "nanded": "Nanded",
    "akola": "Akola",
    "dhule": "Dhule",
    "ahmednagar": "Ahmednagar",
    "ahilya nagar": "Ahilya Nagar",
    "chandrapur": "Chandrapur",
    "parbhani": "Parbhani",
    "ichalkaranji": "Ichalkaranji",
    "jalna": "Jalna",
    "bhiwandi": "Bhiwandi",
    "malegaon": "Malegaon",
    "vapi": "Vapi",
    "anand": "Anand",
    "navsari": "Navsari",
    "bharuch": "Bharuch",
    "morbi": "Morbi",
    "porbandar": "Porbandar",
    "surendranagar": "Surendranagar",
    "mehsana": "Mehsana",
    "bhuj": "Bhuj",
    "gandhinagar": "Gandhinagar",
    "gandhidham": "Gandhidham",
    "jamnagar": "Jamnagar",
    "bhavnagar": "Bhavnagar",
    "junagadh": "Junagadh",
    "udaipur": "Udaipur",
    "bikaner": "Bikaner",
    "ajmer": "Ajmer",
    "bhilwara": "Bhilwara",
    "alwar": "Alwar",
    "sikar": "Sikar",
    "ujjain": "Ujjain",
    "sagar": "Sagar",
    "dewas": "Dewas",
    "satna": "Satna",
    "ratlam": "Ratlam",
    "shimla": "Shimla",
    "haridwar": "Haridwar",
    "roorkee": "Roorkee",
    "dehradun": "Dehradun",
    "panipat": "Panipat",
    "karnal": "Karnal",
    "sonipat": "Sonipat",
    "rohtak": "Rohtak",
    "hisar": "Hisar",
    "bathinda": "Bathinda",
    "patiala": "Patiala",
    "hapur": "Hapur",
    "moradabad": "Moradabad",
    "aligarh": "Aligarh",
    "bareilly": "Bareilly",
    "saharanpur": "Saharanpur",
    "gorakhpur": "Gorakhpur",
    "jhansi": "Jhansi",
    "firozabad": "Firozabad",
    "muzaffarnagar": "Muzaffarnagar",
    "mathura": "Mathura",
    "rampur": "Rampur",
    "shahjahanpur": "Shahjahanpur",
    "etawah": "Etawah",
    "gaya": "Gaya",
    "bhagalpur": "Bhagalpur",
    "muzaffarpur": "Muzaffarpur",
    "purnia": "Purnia",
    "darbhanga": "Darbhanga",
    "bihar sharif": "Bihar Sharif",
    "arrah": "Arrah",
    "begusarai": "Begusarai",
    "katihar": "Katihar",
    "rourkela": "Rourkela",
    "cuttack": "Cuttack",
    "sambalpur": "Sambalpur",
    "puri": "Puri",
    "balasore": "Balasore",
    "durgapur": "Durgapur",
    "asansol": "Asansol",
    "siliguri": "Siliguri",
    "bardhaman": "Bardhaman",
    "kharagpur": "Kharagpur",
    "haldia": "Haldia",
    "bilaspur": "Bilaspur",
    "korba": "Korba",
    "durg": "Durg",
    "bhilai": "Bhilai",
    "rajnandgaon": "Rajnandgaon",
    "jamshedpur": "Jamshedpur",
    "bokaro": "Bokaro",
    "deoghar": "Deoghar",
    "hazaribagh": "Hazaribagh",
    "mangalore": "Mangalore",
    "mangaluru": "Mangalore",
    "belgaum": "Belgaum",
    "belagavi": "Belgaum",
    "davangere": "Davangere",
    "bellary": "Bellary",
    "ballari": "Bellary",
    "shivamogga": "Shivamogga",
    "tumakuru": "Tumakuru",
    "kalaburagi": "Kalaburagi",
    "vijayapura": "Vijayapura",
    "udupi": "Udupi",
    "bidar": "Bidar",
    "hosapete": "Hosapete",
    "guntur": "Guntur",
    "nellore": "Nellore",
    "kurnool": "Kurnool",
    "rajahmundry": "Rajahmundry",
    "kakinada": "Kakinada",
    "tirupati": "Tirupati",
    "kadapa": "Kadapa",
    "anantapur": "Anantapur",
    "eluru": "Eluru",
    "ongole": "Ongole",
    "vizianagaram": "Vizianagaram",
    "machilipatnam": "Machilipatnam",
    "nizamabad": "Nizamabad",
    "khammam": "Khammam",
    "karimnagar": "Karimnagar",
    "ramagundam": "Ramagundam",
    "mahbubnagar": "Mahbubnagar",
    "nalgonda": "Nalgonda",
    "tiruchirappalli": "Tiruchirappalli",
    "trichy": "Tiruchirappalli",
    "tirunelveli": "Tirunelveli",
    "tiruppur": "Tiruppur",
    "erode": "Erode",
    "vellore": "Vellore",
    "thoothukudi": "Thoothukudi",
    "tuticorin": "Thoothukudi",
    "dindigul": "Dindigul",
    "thanjavur": "Thanjavur",
    "ranipet": "Ranipet",
    "sivakasi": "Sivakasi",
    "karur": "Karur",
    "hosur": "Hosur",
    "nagercoil": "Nagercoil",
    "kanchipuram": "Kanchipuram",
    "kollam": "Kollam",
    "thrissur": "Thrissur",
    "alappuzha": "Alappuzha",
    "alleppey": "Alappuzha",
    "palakkad": "Palakkad",
    "kottayam": "Kottayam",
    "kannur": "Kannur",
    "manjeri": "Manjeri",
    "kasaragod": "Kasaragod",
    "agartala": "Agartala",
    "aizawl": "Aizawl",
    "imphal": "Imphal",
    "shillong": "Shillong",
    "kohima": "Kohima",
    "dimapur": "Dimapur",
    "itanagar": "Itanagar",
    "gangtok": "Gangtok",
    "silchar": "Silchar",
    "dibrugarh": "Dibrugarh",
    "jorhat": "Jorhat",
    "nagaon": "Nagaon",
    "tezpur": "Tezpur",
    "port blair": "Port Blair",
    "daman": "Daman",
    "diu": "Diu",
    "silvassa": "Silvassa",
    "jammu": "Jammu",
    "leh": "Leh",
    "sanand": "Sanand",
    "halol": "Halol",
    "manesar": "Manesar",
    "bawal": "Bawal",
    "dharuhera": "Dharuhera",
    "neemrana": "Neemrana",
    "chakan": "Chakan",
    "talegaon": "Talegaon",
    "ranjangaon": "Ranjangaon",
    "rudrapur": "Rudrapur",
    "pantnagar": "Pantnagar",
    "pithampur": "Pithampur",
    "baddi": "Baddi",
}


def _clean_address_part(part: str) -> str:
    """Strips 6-digit Indian PIN code and surrounding punctuation/dashes safely."""
    s = _PIN_REGEX.sub("", part).strip()
    # Strip any leading/trailing dashes, colons, or punctuation
    s = re.sub(
        r"^[\-\u2010\u2012\u2013\u2014\u2015\u2212:,\s]+|[\-\u2010\u2012\u2013\u2014\u2015\u2212:,\s]+$",
        "",
        s,
    )
    return s.strip()


def _check_city_component(comp_clean: str) -> str | None:
    """
    Checks if a cleaned address component is an unambiguous city
    or a city-plus-state component (e.g. 'Ahmedabad - Gujarat').
    Returns standard city display name if recognized, or None.
    """
    comp_lower = comp_clean.lower()

    if comp_lower in COUNTRIES or comp_lower in INDIAN_STATES_AND_UTS:
        return None

    # 1. Exact match with a known city
    if comp_lower in KNOWN_INDIAN_CITIES:
        return KNOWN_INDIAN_CITIES[comp_lower]

    # 2. City-plus-state component (e.g. 'Ahmedabad - Gujarat', 'Pune Maharashtra', 'Navi Mumbai - Maharashtra')
    for state in sorted(INDIAN_STATES_AND_UTS, key=len, reverse=True):
        match = re.search(
            r"[\s\-\u2010\u2012\u2013\u2014\u2015\u2212]+" + re.escape(state) + r"$",
            comp_lower,
        )
        if match:
            prefix = comp_lower[:match.start()].strip(" -\u2010\u2012\u2013\u2014\u2015\u2212")
            if prefix in KNOWN_INDIAN_CITIES:
                return KNOWN_INDIAN_CITIES[prefix]

    return None


def extract_city_from_address(address: str | None) -> str:
    """
    Conservatively extracts a reliable city value from a Partner's registered business address.
    - Accepts a city only when it is identifiable as a complete address component.
    - Supports comma/newline-separated Indian address formats, including city with PIN code
      and city-plus-state components (e.g. 'Ahmedabad - Gujarat').
    - Excludes state names, country names, PIN codes and non-city components.
    - Never guesses a city from a road name, business name, or landmark.
    - Returns 'N/A' if the address does not contain an unambiguous city component.
    """
    if not address or not address.strip():
        return "N/A"

    clean_addr = address.strip()
    if clean_addr.upper() in ("N/A", "NA", "NONE", "UNKNOWN", "NOT AVAILABLE", "-", "NULL"):
        return "N/A"

    lines = clean_addr.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    components: list[str] = []
    for line in lines:
        for p in line.split(","):
            p_strip = p.strip()
            if p_strip:
                components.append(p_strip)

    if not components:
        return "N/A"

    cleaned_components = [_clean_address_part(c) for c in components]
    cleaned_components = [c for c in cleaned_components if c]

    # Check if New Delhi is present among components to avoid selecting 'Delhi' as a city
    has_new_delhi = any(
        _check_city_component(c) == "New Delhi" for c in cleaned_components
    )

    # Evaluate components in reverse order (city appears near the end before state/country)
    for comp in reversed(cleaned_components):
        city = _check_city_component(comp)
        if city is not None:
            if city == "Delhi" and has_new_delhi:
                return "New Delhi"
            return city

    return "N/A"


def extract_clean_order_notes(raw_notes: str | None) -> str | None:
    """
    Extracts genuine order notes entered by the user, excluding internal system metadata
    tags such as [Created by Staff: ...], [idempotency_key:...], [Rejection remarks: ...],
    and generated Flutter notes like 'Placed by Staff for Dealer #123'.
    Returns None if no genuine notes remain after excluding internal metadata.
    """
    if not raw_notes or not raw_notes.strip():
        return None

    clean_lines: list[str] = []
    for line in raw_notes.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        # Exact generated Flutter note format: Placed by Staff for Dealer #123
        if re.match(r"^Placed by Staff for Dealer #\d+$", stripped, flags=re.IGNORECASE):
            continue
        # Remove any inline metadata tags
        cleaned = re.sub(r"\[Created by Staff:[^\]]*\]", "", stripped, flags=re.IGNORECASE)
        cleaned = re.sub(r"\[idempotency_key:[^\]]*\]", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\[Rejection remarks:[^\]]*\]", "", cleaned, flags=re.IGNORECASE)
        cleaned = cleaned.strip()
        if cleaned:
            clean_lines.append(cleaned)

    result = "\n".join(clean_lines).strip()
    return result if result else None


def generate_order_pdf(order: Order) -> bytes:
    """
    Generates an official Sales Order PDF document.
    Redesigned to follow the Sales Order visual layout and structure:
    - Prominent centered title: SALES ORDER
    - Saved Partner/business information (Business name, Address, Transport, Phone)
    - Order information (Order number, Order date)
    - Product table: S. No., Product, Qty., MRP, LIST, Stock (clear borders, snapshots respected)
    - Totals section (Total quantity and final order amount)
    - Signature section
    - Footer with print-time timestamp and Partner registered address city
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        leftMargin=36,
        rightMargin=36,
        topMargin=36,
        bottomMargin=48,
    )

    styles = getSampleStyleSheet()

    # Color Palette matching Score branding
    primary_color = colors.HexColor("#083FA5")
    deep_blue = colors.HexColor("#072763")
    dark_neutral = colors.HexColor("#1A202C")
    light_blue = colors.HexColor("#EBF5FF")
    border_color = colors.HexColor("#94A3B8")
    table_border = colors.HexColor("#64748B")
    muted_text = colors.HexColor("#4A5568")

    # Typography styles
    sales_order_title_style = ParagraphStyle(
        "SalesOrderTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=22,
        leading=26,
        textColor=deep_blue,
        alignment=1,  # Center aligned
    )

    section_heading_style = ParagraphStyle(
        "SectionHeading",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=10,
        leading=14,
        textColor=primary_color,
    )

    info_label_style = ParagraphStyle(
        "InfoLabel",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9,
        leading=13,
        textColor=primary_color,
    )

    info_value_style = ParagraphStyle(
        "InfoValue",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        leading=13,
        textColor=dark_neutral,
    )

    table_header_style = ParagraphStyle(
        "TableHeader",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9,
        leading=12,
        textColor=deep_blue,
        alignment=1,
    )

    table_cell_center = ParagraphStyle(
        "TableCellCenter",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8.5,
        leading=11,
        textColor=dark_neutral,
        alignment=1,
    )

    table_cell_left = ParagraphStyle(
        "TableCellLeft",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8.5,
        leading=11,
        textColor=dark_neutral,
    )

    table_cell_right = ParagraphStyle(
        "TableCellRight",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8.5,
        leading=11,
        textColor=dark_neutral,
        alignment=2,  # Right aligned
    )

    total_label_style = ParagraphStyle(
        "TotalLabel",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9.5,
        leading=13,
        textColor=deep_blue,
        alignment=2,
    )

    total_value_style = ParagraphStyle(
        "TotalValue",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=10,
        leading=13,
        textColor=deep_blue,
        alignment=2,
    )

    story = []

    # -------------------------------------------------------------------------
    # 1. Header: Logo (optional) and Centered Prominent "SALES ORDER" Title
    # -------------------------------------------------------------------------
    logo_path = _find_logo_path()
    logo_widget = None
    if logo_path and logo_path.is_file():
        try:
            logo_widget = Image(str(logo_path), width=1.3 * inch, height=0.48 * inch)
        except Exception:
            logo_widget = None

    if logo_widget:
        header_table = Table(
            [
                [
                    logo_widget,
                    Paragraph("<b>SALES ORDER</b>", sales_order_title_style),
                    Paragraph(
                        f"<b>Score Mobility</b><br/><font size=7.5 color='#64748B'>Official Sales Order</font>",
                        ParagraphStyle("HeadRight", parent=info_value_style, alignment=2),
                    ),
                ]
            ],
            colWidths=[120, 300, 120],
        )
        header_table.setStyle(
            TableStyle(
                [
                    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                    ("ALIGN", (1, 0), (1, 0), "CENTER"),
                    ("TOPPADDING", (0, 0), (-1, -1), 0),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ]
            )
        )
        story.append(header_table)
    else:
        story.append(Paragraph("<b>SALES ORDER</b>", sales_order_title_style))

    story.append(HRFlowable(width="100%", thickness=1.5, color=primary_color, spaceBefore=4, spaceAfter=10))

    # -------------------------------------------------------------------------
    # 2 & 3. Partner / Business Information and Order Information Grid
    # -------------------------------------------------------------------------
    partner = order.partner
    partner_profile = getattr(partner, "partner_profile", None) if partner else None

    business_name = partner_profile.business_name if (partner_profile and partner_profile.business_name) else (partner.name if partner else "N/A")
    partner_address = partner_profile.business_address if (partner_profile and partner_profile.business_address) else "N/A"
    partner_mobile = partner.mobile if (partner and partner.mobile) else "N/A"
    partner_code = partner_profile.partner_code if (partner_profile and partner_profile.partner_code) else "N/A"
    # Never use order.notes as Transport Name. No dedicated field exists; display "-"
    transport_name = "-"

    order_date_str = (
        order.created_at.strftime("%d %b %Y, %I:%M %p")
        if order.created_at
        else datetime.now(timezone.utc).strftime("%d %b %Y, %I:%M %p")
    )
    status_display = order.status.replace("_", " ").upper()

    clean_partner_address = (
        partner_address.replace("\r\n", ", ")
        .replace("\n", ", ")
        .replace("\r", ", ")
    )

    partner_info_cell = [
        Paragraph("<b>Partner / Business Information</b>", section_heading_style),
        Spacer(1, 3),
        Paragraph(f"<b>Business Name:</b> {escape_pdf_text(business_name)}", info_value_style),
        Paragraph(f"<b>Registered Address:</b> {escape_pdf_text(clean_partner_address)}", info_value_style),
        Paragraph(f"<b>Transport Name:</b> {escape_pdf_text(transport_name)}", info_value_style),
        Paragraph(f"<b>Phone Number:</b> {escape_pdf_text(partner_mobile)}", info_value_style),
    ]

    order_info_cell = [
        Paragraph("<b>Order Information</b>", section_heading_style),
        Spacer(1, 3),
        Paragraph(f"<b>Order Number:</b> {escape_pdf_text(order.order_number)}", info_value_style),
        Paragraph(f"<b>Order Date:</b> {escape_pdf_text(order_date_str)}", info_value_style),
        Paragraph(f"<b>Partner Code:</b> {escape_pdf_text(partner_code)}", info_value_style),
        Paragraph(f"<b>Order Status:</b> <b><font color='#083FA5'>{escape_pdf_text(status_display)}</font></b>", info_value_style),
    ]

    meta_grid = [
        [
            partner_info_cell,
            order_info_cell,
        ]
    ]

    meta_table = Table(meta_grid, colWidths=[310, 230])
    meta_table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
                ("BOX", (0, 0), (-1, -1), 1, border_color),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
            ]
        )
    )
    story.append(meta_table)
    story.append(Spacer(1, 12))

    # -------------------------------------------------------------------------
    # 4. Product Table
    # 6 Columns: S. No. | Product | Qty. | MRP | LIST | Stock
    # -------------------------------------------------------------------------
    items = order.items or []
    items_data = [
        [
            Paragraph("<b>S. No.</b>", table_header_style),
            Paragraph("<b>Product</b>", table_header_style),
            Paragraph("<b>Qty.</b>", table_header_style),
            Paragraph("<b>MRP</b>", table_header_style),
            Paragraph("<b>LIST</b>", table_header_style),
            Paragraph("<b>Stock</b>", table_header_style),
        ]
    ]

    total_qty = 0
    calculated_subtotal = Decimal("0.00")
    calculated_discount = Decimal("0.00")

    for idx, item in enumerate(items, start=1):
        product = item.product
        sku = product.product_code if product else f"PRD-{item.product_id}"
        prod_name = product.name if product else f"Product #{item.product_id}"
        qty = item.quantity

        orig_price = (
            Decimal(str(item.original_price))
            if item.original_price is not None
            else Decimal(str(item.unit_price))
        )
        item_mrp = (
            Decimal(str(item.mrp))
            if item.mrp is not None
            else None
        )
        item_list = (
            Decimal(str(item.list_price))
            if item.list_price is not None
            else None
        )
        disc_pct = (
            Decimal(str(item.discount_percentage))
            if item.discount_percentage is not None
            else (
                Decimal(str(order.discount_percentage or 0))
                if order.discount_percentage
                else Decimal("0.00")
            )
        )
        disc_amt = (
            Decimal(str(item.discount_amount))
            if item.discount_amount is not None
            else Decimal("0.00")
        )
        final_price = (
            Decimal(str(item.discounted_price))
            if item.discounted_price is not None
            else Decimal(str(item.unit_price))
        )
        line_total = qty * final_price

        total_qty += qty
        calculated_subtotal += (qty * orig_price)
        calculated_discount += (qty * disc_amt)

        mrp_display = f"Rs. {item_mrp:,.2f}" if item_mrp is not None else "-"
        if item_list is not None:
            list_display = f"Rs. {item_list:,.2f}"
        elif item_mrp is not None:
            list_display = f"Rs. {orig_price:,.2f}*<br/><font size=6.5 color='#64748B'>(Temporary MRP fallback)</font>"
        else:
            list_display = "-"

        # Include product identification and discount/final-price breakdown transparently
        if disc_amt > 0:
            price_details = (
                f"<br/><font size=7 color='#083FA5'>"
                f"Disc: {disc_pct:.1f}% (-Rs. {disc_amt:,.2f}) | Net: Rs. {final_price:,.2f} | Total: Rs. {line_total:,.2f}"
                f"</font>"
            )
        else:
            price_details = (
                f"<br/><font size=7 color='#64748B'>"
                f"Net: Rs. {final_price:,.2f} | Total: Rs. {line_total:,.2f}"
                f"</font>"
            )

        prod_cell_content = (
            f"<b>{escape_pdf_text(prod_name)}</b><br/>"
            f"<font size=7 color='#64748B'>Code: {escape_pdf_text(sku)}</font>"
            f"{price_details}"
        )

        # Stock snapshot limitation: since no stock snapshot column exists in DB,
        # clean fallback '-' is displayed per specification.
        stock_display = "-"

        items_data.append(
            [
                Paragraph(str(idx), table_cell_center),
                Paragraph(prod_cell_content, table_cell_left),
                Paragraph(str(qty), table_cell_center),
                Paragraph(mrp_display, table_cell_right),
                Paragraph(list_display, table_cell_right),
                Paragraph(stock_display, table_cell_center),
            ]
        )

    order_subtotal = (
        Decimal(str(order.subtotal_before_discount))
        if order.subtotal_before_discount is not None
        else calculated_subtotal
    )
    order_discount = (
        Decimal(str(order.total_discount))
        if order.total_discount is not None
        else calculated_discount
    )
    order_final = (
        Decimal(str(order.final_total))
        if order.final_total is not None
        else (order_subtotal - order_discount)
    )

    # -------------------------------------------------------------------------
    # 5. Totals Section (embedded at bottom of table with spanning)
    # -------------------------------------------------------------------------
    # Row 1: Subtotal Before Discount
    items_data.append(
        [
            Paragraph(f"<b>Total Items: {len(items)}</b>", table_cell_left),
            "",
            Paragraph("<b>Subtotal Before Discount:</b>", total_label_style),
            "",
            "",
            Paragraph(f"<b>Rs. {order_subtotal:,.2f}</b>", total_value_style),
        ]
    )

    # Row 2: Discount & Total Quantity
    disc_summary_label = (
        f"<b>Partner Discount ({escape_pdf_text(order.discount_percentage or 0)}%):</b>"
    )
    items_data.append(
        [
            Paragraph(f"<b>Total Quantity: {total_qty}</b>", table_cell_left),
            "",
            Paragraph(disc_summary_label, total_label_style),
            "",
            "",
            Paragraph(f"<b>- Rs. {order_discount:,.2f}</b>", total_value_style),
        ]
    )

    # Row 3: Final Order Total
    items_data.append(
        [
            "",
            "",
            Paragraph("<b>Final Order Total:</b>", total_label_style),
            "",
            "",
            Paragraph(f"<b>Rs. {order_final:,.2f}</b>", total_value_style),
        ]
    )

    # Col widths summing to 540 (printable area width for letter with 36pt margins)
    col_widths = [32, 208, 45, 80, 115, 60]
    items_table = Table(items_data, colWidths=col_widths, repeatRows=1)
    items_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), light_blue),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("BOX", (0, 0), (-1, -1), 1, table_border),
                ("INNERGRID", (0, 0), (-1, -4), 0.5, colors.HexColor("#CBD5E1")),
                # Totals rows styling and spans
                ("BACKGROUND", (0, -3), (-1, -1), colors.HexColor("#F1F5F9")),
                ("LINEABOVE", (0, -3), (-1, -3), 1.2, primary_color),
                ("LINEBELOW", (0, -1), (-1, -1), 1.2, primary_color),
                ("SPAN", (0, -3), (1, -3)),
                ("SPAN", (2, -3), (4, -3)),
                ("SPAN", (0, -2), (1, -2)),
                ("SPAN", (2, -2), (4, -2)),
                ("SPAN", (0, -1), (1, -1)),
                ("SPAN", (2, -1), (4, -1)),
                ("INNERGRID", (0, -3), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
            ]
        )
    )
    story.append(items_table)

    # Temporary MRP fallback explanatory footnote
    has_mrp_fallback = any(
        item.list_price is None and item.mrp is not None for item in items
    )
    if has_mrp_fallback:
        story.append(Spacer(1, 4))
        story.append(
            Paragraph(
                "<font size=7.5 color='#64748B'>* Note: Items marked with (Temporary MRP fallback) use the MRP as the temporary calculation price because List Price was not set.</font>",
                styles["Normal"],
            )
        )
        story.append(Spacer(1, 8))
    else:
        story.append(Spacer(1, 10))

    # -------------------------------------------------------------------------
    # 5. Order Notes Section (if genuine customer notes present)
    # -------------------------------------------------------------------------
    # System metadata tags ([Created by Staff: ...], [idempotency_key:...], [Rejection remarks: ...])
    # must never be exposed as customer-facing notes. If no genuine notes remain, omit section.
    clean_notes = extract_clean_order_notes(order.notes)
    if clean_notes:
        safe_notes = "<br/>".join(
            escape_pdf_text(line) for line in clean_notes.splitlines()
        )
        notes_table = Table(
            [
                [
                    Paragraph(
                        f"<b>Order Notes:</b><br/>{safe_notes}",
                        info_value_style,
                    )
                ]
            ],
            colWidths=[540],
        )
        notes_table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
                    ("BOX", (0, 0), (-1, -1), 0.5, border_color),
                    ("TOPPADDING", (0, 0), (-1, -1), 5),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                    ("LEFTPADDING", (0, 0), (-1, -1), 8),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ]
            )
        )
        story.append(notes_table)
        story.append(Spacer(1, 8))

    # -------------------------------------------------------------------------
    # 6. Signature Section
    # -------------------------------------------------------------------------
    sig_data = [
        [
            Paragraph("<b>Partner / Customer Confirmation</b><br/><font size=7 color='#64748B'>Signature & Stamp</font>", info_value_style),
            Paragraph("<b>Authorized Signatory</b><br/><font size=7 color='#64748B'>For Score Mobility Platform</font>", ParagraphStyle("SigRight", parent=info_value_style, alignment=2)),
        ],
        [
            Spacer(1, 32),
            Spacer(1, 32),
        ],
        [
            Paragraph("____________________________<br/><font size=7.5 color='#4A5568'>Received By / Date</font>", info_value_style),
            Paragraph("____________________________<br/><font size=7.5 color='#4A5568'>Authorized Signature / Date</font>", ParagraphStyle("SigSign", parent=info_value_style, alignment=2)),
        ],
    ]
    sig_table = Table(sig_data, colWidths=[270, 270])
    sig_table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#FAFAFA")),
                ("BOX", (0, 0), (-1, -1), 0.5, border_color),
            ]
        )
    )

    story.append(KeepTogether([sig_table]))

    # -------------------------------------------------------------------------
    # 7. Footer: Actual PDF printing timestamp (Asia/Kolkata IST) and Partner city
    # -------------------------------------------------------------------------
    # Printing timestamp must always use Asia/Kolkata (IST), generated at print time (now), NOT order created_at.
    ist_tz = ZoneInfo("Asia/Kolkata")
    now_print_time = datetime.now(ist_tz).strftime("%d %b %Y, %I:%M %p")
    partner_city = extract_city_from_address(partner_address)

    footer_left_style = ParagraphStyle(
        "SalesOrderFooterLeft",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8,
        leading=10,
        textColor=colors.HexColor("#64748B"),
    )
    footer_right_style = ParagraphStyle(
        "SalesOrderFooterRight",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8,
        leading=10,
        textColor=colors.HexColor("#64748B"),
        alignment=2,
    )

    def _draw_sales_order_footer(canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(colors.HexColor("#CBD5E1"))
        canvas.setLineWidth(0.5)
        canvas.line(36, 36, letter[0] - 36, 36)

        left_markup = (
            f"Print Date & Time: {escape_pdf_text(now_print_time)} | "
            f"City: {escape_pdf_text(partner_city)}"
        )
        right_markup = (
            f"Order #{escape_pdf_text(order.order_number)} | "
            f"Page {canvas._pageNumber}"
        )

        footer_table = Table(
            [
                [
                    Paragraph(left_markup, footer_left_style),
                    Paragraph(right_markup, footer_right_style),
                ]
            ],
            colWidths=[330, 210],
        )
        footer_table.setStyle(
            TableStyle(
                [
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 0),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                    ("TOPPADDING", (0, 0), (-1, -1), 0),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
                ]
            )
        )
        w, h = footer_table.wrap(540, 30)
        footer_table.drawOn(canvas, 36, 34 - h)
        canvas.restoreState()

    doc.build(story, onFirstPage=_draw_sales_order_footer, onLaterPages=_draw_sales_order_footer)
    return buffer.getvalue()
