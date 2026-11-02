from __future__ import annotations

from collections import defaultdict
from pathlib import Path
import sys
from typing import Any

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts import catalogue_import

REPORT_DIR = Path(__file__).resolve().parents[1] / "reports" / "catalogue_review"
PRICE_NUMBER_FORMAT = "0.00############"
SUSPICIOUS_SECTION_LABELS = {"P", "UD", "SB-735 L", "SB-735 R"}

OCCURRENCE_COLUMNS = [
    "Group ID",
    "Workbook",
    "Worksheet",
    "Excel Row",
    "Vehicle Type",
    "Category/Section",
    "Product Code",
    "Product Description",
    "Vehicle Model",
    "Package Quantity",
    "Printed/List Price",
    "Revised/Side Price",
    "Proposed Final Price",
    "Price Source",
    "Source-Row Fingerprint",
    "Classification",
    "Differing Fields",
    "Issues",
    "Review Recommendation",
]

SUMMARY_COLUMNS = [
    "Group ID",
    "Workbook",
    "Worksheet",
    "Vehicle Type",
    "Product Code",
    "Occurrence Count",
    "Excel Rows",
    "Category/Sections",
    "Descriptions",
    "Vehicle Models",
    "Package Quantities",
    "Printed/List Prices",
    "Revised/Side Prices",
    "Proposed Prices",
    "Price Sources",
    "Differing Fields",
    "Classification",
    "Issues",
    "Reason",
    "Review Recommendation",
]

MISSING_PRICE_COLUMNS = [
    "Workbook",
    "Worksheet",
    "Excel Row",
    "Vehicle Type",
    "Category/Section",
    "Product Code",
    "Product Description",
    "Vehicle Model",
    "Package Quantity",
    "Printed/List Price",
    "Revised/Side Price",
    "Proposed Final Price",
    "Price Source",
    "Source-Row Fingerprint",
]

INVALID_COLUMNS = [
    "Workbook",
    "Worksheet",
    "Excel Row",
    "Vehicle Type",
    "Category/Section",
    "Product Code",
    "Product Description",
    "Reason",
    "Source Row",
]

CATEGORY_COLUMNS = [
    "Workbook",
    "Worksheet",
    "Vehicle Type",
    "Category/Section",
    "Review Flag",
]

OVERALL_COLUMNS = [
    "Workbook",
    "Worksheet",
    "Vehicle Type",
    "Rows Inspected",
    "Valid Product Candidates",
    "Excluded Rows",
    "Unclassified Rows",
    "Invalid/Incomplete Rows",
    "Printed-Price Candidates",
    "Updated Side-Price Candidates",
    "Missing-Price Candidates",
    "Ambiguous-Price Rows",
    "Distinct Category/Section Labels",
    "Duplicate-Code Groups",
    "Rows in Duplicate Groups",
    "Additional Occurrences Beyond First",
]


def _candidate_row(
    candidate: catalogue_import.ProductCandidate,
    report: dict[str, Any],
    group_id: str | None = None,
) -> dict[str, Any]:
    proposed_price = (
        candidate.side_price
        if candidate.side_price is not None
        else candidate.list_price
    )
    if candidate.side_price is not None:
        price_source = "side/revised"
    elif candidate.list_price is not None:
        price_source = "printed/list"
    else:
        price_source = "missing"

    return {
        "group_id": group_id,
        "workbook": report["filename"],
        "worksheet": candidate.sheet_name,
        "excel_row": candidate.row_number,
        "vehicle_type": candidate.workbook,
        "category": candidate.category_name,
        "product_code": candidate.code,
        "description": candidate.description,
        "vehicle_model": candidate.vehicle_type,
        "package_quantity": candidate.package_quantity,
        "printed_price": candidate.list_price,
        "side_price": candidate.side_price,
        "proposed_price": proposed_price,
        "price_source": price_source,
        "fingerprint": catalogue_import._source_row_fingerprint(
            candidate.workbook,
            candidate.sheet_name,
            candidate.row_number,
            candidate.code,
            candidate.description,
        ),
    }


def _distinct(values: list[Any]) -> list[Any]:
    distinct: list[Any] = []
    for value in values:
        if value not in distinct:
            distinct.append(value)
    return distinct


def _group_assessment(
    rows: list[dict[str, Any]],
) -> tuple[list[str], list[str], str, str, str]:
    compared_fields = [
        ("category", "category/section"),
        ("description", "description"),
        ("vehicle_model", "vehicle model"),
        ("package_quantity", "package quantity"),
        ("printed_price", "printed/list price"),
        ("side_price", "revised/side price"),
        ("proposed_price", "proposed final price"),
        ("price_source", "price source"),
    ]
    differing_fields = [
        label
        for key, label in compared_fields
        if len(_distinct([row[key] for row in rows])) > 1
    ]

    issues: list[str] = []
    category_conflict = len(_distinct([row["category"] for row in rows])) > 1
    proposed_prices = [row["proposed_price"] for row in rows]
    proposed_price_conflict = len(_distinct(proposed_prices)) > 1
    price_availability_conflict = (
        any(price is None for price in proposed_prices)
        and any(price is not None for price in proposed_prices)
    )

    if category_conflict:
        issues.append("CATEGORY_OR_SECTION_CONFLICT")
    if proposed_price_conflict:
        issues.append("PROPOSED_PRICE_CONFLICT")
    if price_availability_conflict:
        issues.append("PRICE_AVAILABILITY_CONFLICT")
    if len(_distinct([row["printed_price"] for row in rows])) > 1:
        issues.append("PRINTED_PRICE_DIFFERENCE")
    if len(_distinct([row["side_price"] for row in rows])) > 1:
        issues.append("SIDE_PRICE_DIFFERENCE")
    if len(_distinct([row["description"] for row in rows])) > 1:
        issues.append("DESCRIPTION_DIFFERENCE")
    if len(_distinct([row["vehicle_model"] for row in rows])) > 1:
        issues.append("VEHICLE_MODEL_DIFFERENCE")
    if len(_distinct([row["package_quantity"] for row in rows])) > 1:
        issues.append("PACKAGE_QUANTITY_DIFFERENCE")

    descriptors_available = all(
        row["description"] and row["category"] for row in rows
    )
    descriptor_conflict = any(
        issue in issues
        for issue in (
            "DESCRIPTION_DIFFERENCE",
            "VEHICLE_MODEL_DIFFERENCE",
            "PACKAGE_QUANTITY_DIFFERENCE",
        )
    )
    source_price_conflict = any(
        issue in issues
        for issue in ("PRINTED_PRICE_DIFFERENCE", "SIDE_PRICE_DIFFERENCE")
    )

    if not descriptors_available:
        classification = "INSUFFICIENT_INFORMATION"
        recommendation = "MANUAL_REVIEW"
    elif category_conflict:
        classification = "CATEGORY_OR_SECTION_CONFLICT"
        recommendation = "OWNER_CONFIRM_CATEGORY"
    elif proposed_price_conflict or price_availability_conflict or source_price_conflict:
        classification = "PRICE_CONFLICT"
        recommendation = "OWNER_CONFIRM_PRICE"
    elif descriptor_conflict:
        classification = "POSSIBLE_VARIANT_SAME_CODE"
        recommendation = "OWNER_CONFIRM_DISTINCT_PRODUCTS"
    else:
        classification = "POSSIBLE_EXACT_DUPLICATE"
        recommendation = "OWNER_CONFIRM_DUPLICATE"

    if differing_fields:
        reason = "Different extracted fields: " + ", ".join(differing_fields) + "."
    elif not descriptors_available:
        reason = "One or more occurrences lack category/section or description data."
    else:
        reason = (
            "All extracted comparison fields match; matching codes alone do not "
            "confirm that these are the same product."
        )

    return differing_fields, issues, classification, reason, recommendation


def build_review_data(workbook_reports: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    occurrence_rows: list[dict[str, Any]] = []
    group_summaries: list[dict[str, Any]] = []
    missing_price_rows: list[dict[str, Any]] = []
    invalid_rows: list[dict[str, Any]] = []
    ambiguous_rows: list[dict[str, Any]] = []
    category_rows: list[dict[str, Any]] = []
    overall_rows: list[dict[str, Any]] = []

    for report in workbook_reports:
        by_code: dict[str, list[catalogue_import.ProductCandidate]] = defaultdict(list)
        candidate_rows = [
            _candidate_row(candidate, report)
            for candidate in report["valid_products"]
        ]
        for candidate, row in zip(report["valid_products"], candidate_rows):
            by_code[candidate.code].append(candidate)
            if row["proposed_price"] is None:
                missing_price_rows.append(row)

        duplicate_group_count = 0
        duplicate_occurrence_count = 0
        additional_occurrences = 0

        for code in sorted(by_code):
            candidates = by_code[code]
            if len(candidates) < 2:
                continue

            duplicate_group_count += 1
            duplicate_occurrence_count += len(candidates)
            additional_occurrences += len(candidates) - 1
            group_id = f"{report['workbook']}-{code}"
            rows = [
                _candidate_row(candidate, report, group_id)
                for candidate in candidates
            ]
            differing_fields, issues, classification, reason, recommendation = (
                _group_assessment(rows)
            )

            for row in rows:
                row.update(
                    {
                        "classification": classification,
                        "differing_fields": differing_fields,
                        "issues": issues,
                        "recommendation": recommendation,
                    }
                )
                occurrence_rows.append(row)

            group_summaries.append(
                {
                    "group_id": group_id,
                    "workbook": report["filename"],
                    "worksheet": report["sheet_name"],
                    "vehicle_type": report["workbook"],
                    "product_code": code,
                    "occurrence_count": len(rows),
                    "excel_rows": [row["excel_row"] for row in rows],
                    "categories": _distinct([row["category"] for row in rows]),
                    "descriptions": _distinct([row["description"] for row in rows]),
                    "vehicle_models": _distinct(
                        [row["vehicle_model"] for row in rows]
                    ),
                    "package_quantities": _distinct(
                        [row["package_quantity"] for row in rows]
                    ),
                    "printed_prices": _distinct(
                        [row["printed_price"] for row in rows]
                    ),
                    "side_prices": _distinct([row["side_price"] for row in rows]),
                    "proposed_prices": _distinct(
                        [row["proposed_price"] for row in rows]
                    ),
                    "price_sources": _distinct(
                        [row["price_source"] for row in rows]
                    ),
                    "differing_fields": differing_fields,
                    "classification": classification,
                    "issues": issues,
                    "reason": reason,
                    "recommendation": recommendation,
                }
            )

        for invalid in report["invalid_row_details"]:
            invalid_rows.append(
                {
                    "workbook": report["filename"],
                    "worksheet": invalid["worksheet_name"],
                    "excel_row": invalid["row_number"],
                    "vehicle_type": invalid["vehicle_type"],
                    "category": invalid["category_name"],
                    "product_code": invalid["code"],
                    "description": invalid["description"],
                    "reason": invalid["reason"],
                    "source_row": " | ".join(invalid["source_row"]),
                }
            )

        for ambiguous in report["ambiguous_price_details"]:
            ambiguous_rows.append(
                {
                    "workbook": report["filename"],
                    "worksheet": ambiguous["worksheet_name"],
                    "excel_row": ambiguous["row_number"],
                    "vehicle_type": ambiguous["vehicle_type"],
                    "category": ambiguous["category_name"],
                    "product_code": ambiguous["code"],
                    "description": ambiguous["description"],
                    "printed_price": ambiguous["printed_price"],
                    "side_price": ambiguous["side_price"],
                    "additional_price_values": ambiguous[
                        "additional_price_values"
                    ],
                    "source_row": " | ".join(ambiguous["source_row"]),
                }
            )

        for section in report["all_section_values"]:
            category_rows.append(
                {
                    "workbook": report["filename"],
                    "worksheet": report["sheet_name"],
                    "vehicle_type": report["workbook"],
                    "category": section,
                    "review_flag": (
                        "SUSPICIOUS LABEL - OWNER REVIEW"
                        if section in SUSPICIOUS_SECTION_LABELS
                        else None
                    ),
                }
            )

        overall_rows.append(
            {
                "workbook": report["filename"],
                "worksheet": report["sheet_name"],
                "vehicle_type": report["workbook"],
                "rows_inspected": report["rows_inspected"],
                "valid_candidates": len(report["valid_products"]),
                "excluded_rows": report[
                    "rows_excluded_as_headings_or_non_products"
                ],
                "unclassified_rows": max(
                    report["rows_inspected"]
                    - len(report["valid_products"])
                    - report["rows_excluded_as_headings_or_non_products"]
                    - report["invalid_or_incomplete_rows"],
                    0,
                ),
                "invalid_rows": report["invalid_or_incomplete_rows"],
                "printed_price_candidates": report["products_with_printed_prices"],
                "side_price_candidates": report["products_using_updated_side_prices"],
                "missing_price_candidates": len(
                    [
                        row
                        for row in candidate_rows
                        if row["proposed_price"] is None
                    ]
                ),
                "ambiguous_price_rows": len(report["ambiguous_price_details"]),
                "distinct_category_labels": len(report["all_section_values"]),
                "duplicate_code_groups": duplicate_group_count,
                "rows_in_duplicate_groups": duplicate_occurrence_count,
                "additional_occurrences": additional_occurrences,
            }
        )

    return {
        "occurrences": occurrence_rows,
        "groups": group_summaries,
        "missing_prices": missing_price_rows,
        "invalid_rows": invalid_rows,
        "ambiguous_prices": ambiguous_rows,
        "categories": category_rows,
        "overall": overall_rows,
    }


def _display(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, list):
        return ", ".join(_display(item) for item in value)
    return str(value)


def _markdown_cell(value: Any) -> str:
    return _display(value).replace("|", "\\|").replace("\n", "<br>")


def _write_sheet(
    workbook: Workbook,
    title: str,
    columns: list[str],
    rows: list[dict[str, Any]],
    field_map: list[str],
) -> None:
    worksheet = workbook.create_sheet(title)
    worksheet.append(columns)
    for row in rows:
        worksheet.append(
            [
                _display(value) if isinstance(value := row.get(field), list) else value
                for field in field_map
            ]
        )

    worksheet.freeze_panes = "A2"
    worksheet.auto_filter.ref = worksheet.dimensions
    for cell in worksheet[1]:
        cell.fill = PatternFill("solid", fgColor="0B3D70")
        cell.font = Font(color="FFFFFF", bold=True)
        cell.alignment = Alignment(wrap_text=True, vertical="center")
    worksheet.row_dimensions[1].height = 30

    for column_index in range(1, len(columns) + 1):
        values = [
            _display(worksheet.cell(row=row_index, column=column_index).value)
            for row_index in range(1, worksheet.max_row + 1)
        ]
        width = min(max(max((len(value) for value in values), default=0) + 2, 12), 55)
        worksheet.column_dimensions[get_column_letter(column_index)].width = width

    for row in worksheet.iter_rows(min_row=2):
        for cell in row:
            cell.alignment = Alignment(vertical="top", wrap_text=True)
            if cell.column in (
                columns.index("Printed/List Price") + 1
                if "Printed/List Price" in columns
                else -1,
                columns.index("Revised/Side Price") + 1
                if "Revised/Side Price" in columns
                else -1,
                columns.index("Proposed Final Price") + 1
                if "Proposed Final Price" in columns
                else -1,
                columns.index("Printed/List Prices") + 1
                if "Printed/List Prices" in columns
                else -1,
                columns.index("Revised/Side Prices") + 1
                if "Revised/Side Prices" in columns
                else -1,
                columns.index("Proposed Prices") + 1
                if "Proposed Prices" in columns
                else -1,
            ):
                cell.number_format = PRICE_NUMBER_FORMAT


def write_excel_report(review_data: dict[str, list[dict[str, Any]]], path: Path) -> None:
    workbook = Workbook()
    workbook.remove(workbook.active)
    sheets = [
        (
            "Duplicate Groups",
            OCCURRENCE_COLUMNS,
            review_data["occurrences"],
            [
                "group_id", "workbook", "worksheet", "excel_row", "vehicle_type",
                "category", "product_code", "description", "vehicle_model",
                "package_quantity", "printed_price", "side_price", "proposed_price",
                "price_source", "fingerprint", "classification",
                "differing_fields", "issues", "recommendation",
            ],
        ),
        (
            "Group Summary",
            SUMMARY_COLUMNS,
            review_data["groups"],
            [
                "group_id", "workbook", "worksheet", "vehicle_type", "product_code",
                "occurrence_count", "excel_rows", "categories", "descriptions",
                "vehicle_models", "package_quantities", "printed_prices",
                "side_prices", "proposed_prices", "price_sources", "differing_fields",
                "classification", "issues", "reason", "recommendation",
            ],
        ),
        (
            "Missing Prices",
            MISSING_PRICE_COLUMNS,
            review_data["missing_prices"],
            [
                "workbook", "worksheet", "excel_row", "vehicle_type", "category",
                "product_code", "description", "vehicle_model", "package_quantity",
                "printed_price", "side_price", "proposed_price", "price_source",
                "fingerprint",
            ],
        ),
        (
            "Invalid Rows",
            INVALID_COLUMNS,
            review_data["invalid_rows"],
            [
                "workbook", "worksheet", "excel_row", "vehicle_type", "category",
                "product_code", "description", "reason", "source_row",
            ],
        ),
        (
            "Category Summary",
            CATEGORY_COLUMNS,
            review_data["categories"],
            ["workbook", "worksheet", "vehicle_type", "category", "review_flag"],
        ),
        (
            "Overall Summary",
            OVERALL_COLUMNS,
            review_data["overall"],
            [
                "workbook", "worksheet", "vehicle_type", "rows_inspected",
                "valid_candidates", "excluded_rows", "unclassified_rows",
                "invalid_rows",
                "printed_price_candidates", "side_price_candidates",
                "missing_price_candidates", "ambiguous_price_rows",
                "distinct_category_labels", "duplicate_code_groups",
                "rows_in_duplicate_groups", "additional_occurrences",
            ],
        ),
        (
            "Ambiguous Prices",
            [
                "Workbook", "Worksheet", "Excel Row", "Vehicle Type",
                "Category/Section", "Product Code", "Product Description",
                "Printed/List Price", "Revised/Side Price",
                "Additional Price Values", "Source Row",
            ],
            review_data["ambiguous_prices"],
            [
                "workbook", "worksheet", "excel_row", "vehicle_type", "category",
                "product_code", "description", "printed_price", "side_price",
                "additional_price_values", "source_row",
            ],
        ),
    ]
    for title, columns, rows, fields in sheets:
        _write_sheet(workbook, title, columns, rows, fields)
    path.parent.mkdir(parents=True, exist_ok=True)
    workbook.save(path)


def write_markdown_report(
    review_data: dict[str, list[dict[str, Any]]], path: Path
) -> None:
    lines = [
        "# Catalogue Duplicate Product-Code Review",
        "",
        "This report preserves every parsed source occurrence. Matching product codes "
        "are not treated as proof that records represent the same product.",
        "",
        "## Reconciliation summary",
        "",
        "| Workbook | Vehicle type | Inspected | Valid | Excluded | Unclassified | Invalid | Missing prices | Ambiguous prices | Duplicate-code groups | Rows in groups | Additional occurrences |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in review_data["overall"]:
        values = [
            row["workbook"], row["vehicle_type"], row["rows_inspected"],
            row["valid_candidates"], row["excluded_rows"], row["unclassified_rows"],
            row["invalid_rows"],
            row["missing_price_candidates"], row["ambiguous_price_rows"],
            row["duplicate_code_groups"], row["rows_in_duplicate_groups"],
            row["additional_occurrences"],
        ]
        lines.append("| " + " | ".join(_markdown_cell(value) for value in values) + " |")

    lines.extend(["", "## Classification counts", ""])
    classifications: dict[str, int] = defaultdict(int)
    for group in review_data["groups"]:
        classifications[group["classification"]] += 1
    lines.extend(
        [
            "| Classification | Groups |",
            "|---|---:|",
        ]
    )
    for classification, count in sorted(classifications.items()):
        lines.append(f"| {classification} | {count} |")

    lines.extend(["", "## Duplicate groups", ""])
    for group in review_data["groups"]:
        lines.extend(
            [
                f"### {group['group_id']}",
                "",
                f"- Workbook/worksheet: {group['workbook']} / {group['worksheet']}",
                f"- Occurrences: {group['occurrence_count']} (Excel rows: "
                f"{_display(group['excel_rows'])})",
                f"- Classification: `{group['classification']}`",
                f"- Differing fields: {_display(group['differing_fields']) or 'none'}",
                f"- Issues: {_display(group['issues']) or 'none'}",
                f"- Evidence: {group['reason']}",
                f"- Recommended action: `{group['recommendation']}`",
                "",
                "| Row | Category/section | Description | Model | Package | Printed/list | Revised/side | Proposed | Price source | Fingerprint |",
                "|---:|---|---|---|---|---:|---:|---:|---|---|",
            ]
        )
        for occurrence in review_data["occurrences"]:
            if occurrence["group_id"] != group["group_id"]:
                continue
            values = [
                occurrence["excel_row"], occurrence["category"],
                occurrence["description"], occurrence["vehicle_model"],
                occurrence["package_quantity"], occurrence["printed_price"],
                occurrence["side_price"], occurrence["proposed_price"],
                occurrence["price_source"], occurrence["fingerprint"],
            ]
            lines.append(
                "| " + " | ".join(_markdown_cell(value) for value in values) + " |"
            )
        lines.append("")

    lines.extend(
        [
            "## Repeated-code issue indexes",
            "",
        ]
    )
    issue_sections = [
        ("Groups with differing category/section labels", "CATEGORY_OR_SECTION_CONFLICT"),
        ("Groups with differing package quantities", "PACKAGE_QUANTITY_DIFFERENCE"),
        ("Groups with differing proposed prices", "PROPOSED_PRICE_CONFLICT"),
        ("Groups with priced and unpriced occurrences", "PRICE_AVAILABILITY_CONFLICT"),
    ]
    for title, issue in issue_sections:
        lines.extend([f"### {title}", ""])
        matching = [group for group in review_data["groups"] if issue in group["issues"]]
        if not matching:
            lines.extend(["None found.", ""])
            continue
        for group in matching:
            lines.append(
                f"- `{group['group_id']}`: rows {_display(group['excel_rows'])}; "
                f"{issue}."
            )
        lines.append("")

    lines.extend(["## Missing-price candidates", ""])
    if review_data["missing_prices"]:
        lines.extend(
            [
                "| Workbook | Row | Code | Description | Section | Package | Printed/list | Revised/side | Proposed | Source |",
                "|---|---:|---|---|---|---|---:|---:|---:|---|",
            ]
        )
        for row in review_data["missing_prices"]:
            values = [
                row["workbook"], row["excel_row"], row["product_code"],
                row["description"], row["category"], row["package_quantity"],
                row["printed_price"], row["side_price"], row["proposed_price"],
                row["price_source"],
            ]
            lines.append(
                "| " + " | ".join(_markdown_cell(value) for value in values) + " |"
            )
    else:
        lines.append("None found.")
    lines.append("")

    lines.extend(["## Ambiguous-price rows", ""])
    if review_data["ambiguous_prices"]:
        for row in review_data["ambiguous_prices"]:
            lines.append(
                f"- {row['workbook']} row {row['excel_row']} ({row['product_code']}): "
                f"additional numeric values "
                f"{_display(row['additional_price_values'])}; manual price review required."
            )
    else:
        lines.append("None found.")
    lines.append("")

    lines.extend(["## Invalid/incomplete rows", ""])
    if review_data["invalid_rows"]:
        for row in review_data["invalid_rows"]:
            lines.append(
                f"- {row['workbook']} row {row['excel_row']} "
                f"(code `{row['product_code']}`): {row['reason']}; "
                f"section `{row['category']}`."
            )
    else:
        lines.append("None found.")
    lines.append("")

    lines.extend(["## Distinct category/section labels", ""])
    for overall in review_data["overall"]:
        labels = [
            row for row in review_data["categories"]
            if row["workbook"] == overall["workbook"]
        ]
        lines.extend(
            [
                f"### {overall['vehicle_type']} - {overall['workbook']}",
                "",
            ]
        )
        if not labels:
            lines.extend(["No section labels were discovered.", ""])
            continue
        lines.append(", ".join(f"`{row['category']}`" for row in labels))
        lines.append("")
        suspicious = [
            row["category"]
            for row in labels
            if row["review_flag"] is not None
        ]
        if suspicious:
            lines.append(
                "Potentially suspicious section labels (review flags, not confirmed "
                "errors): "
                + ", ".join(f"`{label}`" for label in suspicious)
                + "."
            )
            lines.append("")

    lines.extend(
        [
            "## Owner decisions required",
            "",
            "Review every duplicate group and approve whether the rows are distinct "
            "products, duplicate records, or need further clarification. Confirm "
            "price conflicts, category/section conflicts, and all suspicious section "
            "labels manually. No products, prices, or categories were changed by "
            "this report.",
            "",
            "Review actions use `OWNER_CONFIRM_DISTINCT_PRODUCTS`, "
            "`OWNER_CONFIRM_DUPLICATE`, `OWNER_CONFIRM_PRICE`, "
            "`OWNER_CONFIRM_CATEGORY`, or `MANUAL_REVIEW` as appropriate.",
            "",
        ]
    )

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def generate_reports(output_dir: Path = REPORT_DIR) -> tuple[Path, Path, dict[str, list[dict[str, Any]]]]:
    workbook_reports = [
        catalogue_import._build_report_for_workbook(vehicle_type, spec["filename"], spec["sheet_name"])
        for vehicle_type, spec in catalogue_import.WORKBOOK_SPECS.items()
    ]
    review_data = build_review_data(workbook_reports)

    for source_report, summary in zip(workbook_reports, review_data["overall"]):
        if (
            source_report["repeated_product_codes"]
            != summary["duplicate_code_groups"]
            or source_report["affected_repeat_rows"]
            != summary["additional_occurrences"]
            or source_report["products_with_missing_prices"]
            != summary["missing_price_candidates"]
        ):
            raise ValueError(
                f"Review totals do not reconcile with parser output for "
                f"{source_report['workbook']}."
            )

    excel_path = output_dir / "duplicate_product_code_review.xlsx"
    markdown_path = output_dir / "duplicate_product_code_review.md"
    write_excel_report(review_data, excel_path)
    write_markdown_report(review_data, markdown_path)
    return excel_path, markdown_path, review_data


if __name__ == "__main__":
    excel_file, markdown_file, data = generate_reports()
    print(f"Excel report: {excel_file}")
    print(f"Markdown report: {markdown_file}")
    for summary in data["overall"]:
        print(
            f"{summary['vehicle_type']}: inspected={summary['rows_inspected']}, "
            f"valid={summary['valid_candidates']}, "
            f"excluded={summary['excluded_rows']}, "
            f"invalid={summary['invalid_rows']}, "
            f"missing_prices={summary['missing_price_candidates']}, "
            f"duplicate_groups={summary['duplicate_code_groups']}, "
            f"duplicate_rows={summary['rows_in_duplicate_groups']}, "
            f"additional_occurrences={summary['additional_occurrences']}"
        )
