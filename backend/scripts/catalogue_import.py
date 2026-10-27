from __future__ import annotations

import argparse
import hashlib
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from openpyxl import load_workbook

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

DATA_DIR = ROOT_DIR / "data"

WORKBOOK_SPECS = {
    "2-Wheeler": {
        "filename": "2W PRISE LIST  01-10-2026.xlsx",
        "sheet_name": "01-10-26",
    },
    "3-Wheeler": {
        "filename": "3W PRISE LIST  01-10-2026.xlsx",
        "sheet_name": "01-08-26",
    },
}

HEADER_TOKENS = {
    "sr. no",
    "sr.no",
    "code",
    "no.",
    "part name",
    "description",
    "vehicle",
    "new item",
    "new",
    "std.",
    "pkg.",
    "pkg",
    "list",
    "new list",
}

IGNORED_SECTION_TOKENS = {"none", "null"}

CODE_RE = re.compile(r"^[A-Z0-9/\-]+$")
NUMERIC_RE = re.compile(r"^\d+(?:\.\d+)?$")


@dataclass
class ProductCandidate:
    workbook: str
    sheet_name: str
    row_number: int
    code: str
    category_name: str | None
    description: str
    vehicle_type: str | None
    list_price: float | None
    side_price: float | None
    package_quantity: str | None
    source_row: list[str]


def _clean_text(value: Any) -> str:
    return "" if value is None else str(value).strip()


def _is_numeric_like(value: Any) -> bool:
    if isinstance(value, bool):
        return False
    if isinstance(value, (int, float)):
        return True
    if isinstance(value, str):
        return bool(NUMERIC_RE.fullmatch(value.strip().replace(",", "")))
    return False


def _coerce_number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        token = value.strip().replace(",", "")
        if NUMERIC_RE.fullmatch(token):
            return float(token)
    return None


def _source_row_fingerprint(workbook_name: str, sheet_name: str, row_number: int, code: str, description: str) -> str:
    payload = f"{workbook_name}|{sheet_name}|{row_number}|{code}|{description}".encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _build_report_for_workbook(workbook_name: str, filename: str, sheet_name: str) -> dict[str, Any]:
    path = DATA_DIR / filename
    if not path.exists():
        raise FileNotFoundError(f"Missing required workbook: {path}")

    workbook = load_workbook(path, read_only=True, data_only=True)
    if sheet_name not in workbook.sheetnames:
        raise ValueError(f"Worksheet '{sheet_name}' not found in {filename}")

    sheet = workbook[sheet_name]
    valid_products: list[ProductCandidate] = []
    sections: set[str] = set()
    excluded_rows = 0
    invalid_rows = 0
    missing_prices = 0
    printed_prices = 0
    updated_side_prices = 0
    ambiguous_prices = 0
    repeated_codes: dict[str, int] = {}
    representative_rows: list[dict[str, Any]] = []
    invalid_row_details: list[dict[str, Any]] = []
    current_section = "Uncategorised"

    for row_index, row in enumerate(sheet.iter_rows(values_only=True), start=1):
        nonempty = [(idx, value) for idx, value in enumerate(row) if value is not None and _clean_text(value) != ""]
        if not nonempty:
            continue

        first_value = _clean_text(nonempty[0][1])
        if not first_value:
            continue

        first_lower = first_value.lower()
        if first_lower in HEADER_TOKENS or first_lower == "new item":
            continue

        if not CODE_RE.fullmatch(first_value) or len(first_value) < 3:
            if first_value.lower() not in IGNORED_SECTION_TOKENS:
                current_section = first_value
                sections.add(first_value)
            excluded_rows += 1
            continue

        source_values = [_clean_text(value) for _, value in nonempty]
        code = source_values[0]
        description = source_values[1] if len(source_values) > 1 else ""
        vehicle_type = None
        package_quantity = None
        price_values: list[float] = []
        trailing_text: list[str] = []

        for value in source_values[2:]:
            if _is_numeric_like(value):
                number = _coerce_number(value)
                if number is not None:
                    price_values.append(number)
                    continue
            trailing_text.append(value)

        if not description:
            invalid_rows += 1
            invalid_row_details.append({
                "row_number": row_index,
                "code": code,
                "reason": "description missing",
            })
            continue

        if price_values:
            list_price = price_values[0]
            side_price = price_values[1] if len(price_values) > 1 else None
        else:
            list_price = None
            side_price = None

        if side_price is not None and abs(side_price - list_price) < 0.0001:
            side_price = None

        if side_price is not None:
            updated_side_prices += 1
        elif list_price is None:
            missing_prices += 1
        else:
            printed_prices += 1

        if len(price_values) > 2:
            ambiguous_prices += 1

        for token in trailing_text:
            text = _clean_text(token)
            if not text:
                continue
            if re.search(r"(pc|set|kit|net rate|rate)", text.lower()):
                package_quantity = text
            elif vehicle_type is None and not re.search(r"(pc|set|kit|rate)", text.lower()):
                vehicle_type = text

        if list_price is None:
            missing_prices += 1

        candidate = ProductCandidate(
            workbook=workbook_name,
            sheet_name=sheet_name,
            row_number=row_index,
            code=code,
            category_name=current_section,
            description=description,
            vehicle_type=vehicle_type,
            list_price=list_price,
            side_price=side_price,
            package_quantity=package_quantity,
            source_row=source_values,
        )
        valid_products.append(candidate)

        repeated_codes[code] = repeated_codes.get(code, 0) + 1

        if len(representative_rows) < 10:
            representative_rows.append(
                {
                    "row_number": row_index,
                    "code": code,
                    "description": description,
                    "model": vehicle_type,
                    "package_quantity": package_quantity,
                    "printed_price": list_price,
                    "side_price": side_price,
                    "proposed_price": side_price if side_price is not None else list_price,
                    "source_row_fingerprint": _source_row_fingerprint(workbook_name, sheet_name, row_index, code, description),
                }
            )

    duplicate_code_rows = sum(count - 1 for count in repeated_codes.values() if count > 1)
    repeated_code_count = sum(1 for count in repeated_codes.values() if count > 1)

    return {
        "workbook": workbook_name,
        "filename": filename,
        "sheet_name": sheet_name,
        "rows_inspected": sheet.max_row,
        "valid_product_candidates": len(valid_products),
        "distinct_category_values": len(sections),
        "products_with_printed_prices": printed_prices,
        "products_using_updated_side_prices": updated_side_prices,
        "products_with_missing_prices": missing_prices,
        "ambiguous_prices": ambiguous_prices,
        "repeated_product_codes": repeated_code_count,
        "affected_repeat_rows": duplicate_code_rows,
        "rows_excluded_as_headings_or_non_products": excluded_rows,
        "invalid_or_incomplete_rows": invalid_rows,
        "invalid_row_details": invalid_row_details,
        "section_values": sorted(sections)[:25],
        "representative_rows": representative_rows,
        "valid_products": valid_products,
    }


def _render_report(report: dict[str, Any]) -> None:
    print(f"Workbook: {report['workbook']} ({report['filename']})")
    print(f"Visible worksheet: {report['sheet_name']}")
    print(f"Rows inspected: {report['rows_inspected']}")
    print(f"Valid product candidates: {report['valid_product_candidates']}")
    print(f"Distinct category/section values: {report['distinct_category_values']}")
    print(f"Products with printed prices: {report['products_with_printed_prices']}")
    print(f"Products using updated side prices: {report['products_using_updated_side_prices']}")
    print(f"Products with missing prices (NULL candidates): {report['products_with_missing_prices']}")
    print(f"Ambiguous prices requiring review: {report['ambiguous_prices']}")
    print(f"Repeated product codes: {report['repeated_product_codes']}")
    print(f"Affected repeated rows: {report['affected_repeat_rows']}")
    print(f"Rows excluded as headings or non-products: {report['rows_excluded_as_headings_or_non_products']}")
    print(f"Invalid or incomplete rows: {report['invalid_or_incomplete_rows']}")
    if report.get('invalid_row_details'):
        print("Invalid row reasons:")
        for reason in report['invalid_row_details'][:10]:
            print(f"  - row {reason['row_number']}: {reason['reason']} (code={reason['code']})")
    print(f"Sample sections: {', '.join(report['section_values']) if report['section_values'] else 'none'}")
    print("Representative rows:")
    for row in report["representative_rows"]:
        print(
            "  - row {row_number}: code={code}, description={description}, model={model}, "
            "package={package_quantity}, printed={printed_price}, side={side_price}, proposed={proposed_price}".format(**{k: v for k, v in row.items() if k != "source_row_fingerprint"})
        )
    print()


def _import_workbooks() -> None:
    from decimal import Decimal

    from sqlalchemy import create_engine, text

    from app.core.config import settings
    from app.models import Product, ProductCategory

    if not settings.database_url:
        raise RuntimeError("DATABASE_URL is not configured. Set it in backend/.env before importing catalogue data.")

    engine = create_engine(settings.database_url, pool_pre_ping=True)
    with engine.begin() as conn:
        existing_rows = set(
            conn.execute(
                text("SELECT source_row_fingerprint FROM catalogue_import_audit")
            ).scalars().all()
        )

        for workbook_name, spec in WORKBOOK_SPECS.items():
            report = _build_report_for_workbook(workbook_name, spec["filename"], spec["sheet_name"])
            for candidate in report["valid_products"]:
                fingerprint = _source_row_fingerprint(
                    candidate.workbook,
                    candidate.sheet_name,
                    candidate.row_number,
                    candidate.code,
                    candidate.description,
                )
                if fingerprint in existing_rows:
                    continue

                category_name = (candidate.category_name or "Uncategorised").strip() or "Uncategorised"
                category = conn.execute(
                    text("SELECT id FROM product_categories WHERE lower(name) = lower(:name) LIMIT 1"),
                    {"name": category_name},
                ).scalar_one_or_none()
                if category is None:
                    result = conn.execute(
                        text(
                            "INSERT INTO product_categories (name, description, is_active) VALUES (:name, :description, TRUE) RETURNING id"
                        ),
                        {"name": category_name, "description": f"Imported from {candidate.workbook} / {candidate.sheet_name}"},
                    )
                    category = result.scalar_one()

                product_price = candidate.side_price if candidate.side_price is not None else candidate.list_price
                product_name = candidate.description[:200]
                product_code = candidate.code[:50]
                vehicle_type = candidate.vehicle_type or ""
                normalized_vehicle = vehicle_type.strip()
                if normalized_vehicle.lower() == "both":
                    vehicle_type = "Both"
                elif workbook_name == "2-Wheeler":
                    vehicle_type = "2-Wheeler"
                else:
                    vehicle_type = "3-Wheeler"

                conn.execute(
                    text(
                        """
                        INSERT INTO products (
                            category_id,
                            product_code,
                            name,
                            description,
                            vehicle_type,
                            price,
                            image_url,
                            is_active
                        ) VALUES (
                            :category_id,
                            :product_code,
                            :name,
                            :description,
                            :vehicle_type,
                            :price,
                            NULL,
                            TRUE
                        )
                        """
                    ),
                    {
                        "category_id": category,
                        "product_code": product_code,
                        "name": product_name,
                        "description": candidate.description if candidate.description else None,
                        "vehicle_type": vehicle_type,
                        "price": None if product_price is None else Decimal(str(product_price)),
                    },
                )
                product_id = conn.execute(
                    text("SELECT id FROM products WHERE product_code = :product_code AND name = :name AND category_id = :category_id ORDER BY id DESC LIMIT 1"),
                    {"product_code": product_code, "name": product_name, "category_id": category},
                ).scalar_one()

                conn.execute(
                    text(
                        "INSERT INTO catalogue_import_audit (workbook_name, worksheet_name, excel_row_number, product_code, product_name, source_row_fingerprint) VALUES (:workbook_name, :worksheet_name, :excel_row_number, :product_code, :product_name, :source_row_fingerprint)"
                    ),
                    {
                        "workbook_name": candidate.workbook,
                        "worksheet_name": candidate.sheet_name,
                        "excel_row_number": candidate.row_number,
                        "product_code": product_code,
                        "product_name": product_name,
                        "source_row_fingerprint": fingerprint,
                    },
                )

                existing_rows.add(fingerprint)

    print("Catalogue import completed successfully.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Inspect and dry-run the catalogue import before any database changes.")
    parser.add_argument("--dry-run", action="store_true", help="Run the inspection without making any database changes.")
    parser.add_argument("--import", dest="import_mode", action="store_true", help="Execute the catalogue import against the configured local PostgreSQL database.")
    args = parser.parse_args()

    if args.import_mode:
        _import_workbooks()
        return

    if not args.dry_run:
        parser.error("No action requested. Use --dry-run to inspect only or --import to run the approved import flow.")

    for workbook_name, spec in WORKBOOK_SPECS.items():
        _render_report(_build_report_for_workbook(workbook_name, spec["filename"], spec["sheet_name"]))


if __name__ == "__main__":
    main()
