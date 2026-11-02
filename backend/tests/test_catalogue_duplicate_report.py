from pathlib import Path

from openpyxl import load_workbook

from scripts import catalogue_duplicate_report as duplicate_report
from scripts.catalogue_import import ProductCandidate


def _candidate(
    *,
    vehicle_type: str,
    row_number: int,
    code: str,
    category: str | None,
    description: str,
    model: str | None = None,
    package: str | None = None,
    list_price: float | None = None,
    side_price: float | None = None,
) -> ProductCandidate:
    return ProductCandidate(
        workbook=vehicle_type,
        sheet_name="Test Sheet",
        row_number=row_number,
        code=code,
        category_name=category,
        description=description,
        vehicle_type=model,
        list_price=list_price,
        side_price=side_price,
        package_quantity=package,
        source_row=[code, description],
    )


def _workbook_report(
    vehicle_type: str,
    filename: str,
    candidates: list[ProductCandidate],
    *,
    sections: list[str],
    invalid_rows: list[dict[str, object]] | None = None,
    ambiguous_rows: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    missing_count = sum(
        candidate.list_price is None and candidate.side_price is None
        for candidate in candidates
    )
    code_counts: dict[str, int] = {}
    for candidate in candidates:
        code_counts[candidate.code] = code_counts.get(candidate.code, 0) + 1
    return {
        "workbook": vehicle_type,
        "filename": filename,
        "sheet_name": "Test Sheet",
        "rows_inspected": 12,
        "valid_product_candidates": len(candidates),
        "products_with_printed_prices": sum(
            candidate.list_price is not None and candidate.side_price is None
            for candidate in candidates
        ),
        "products_using_updated_side_prices": sum(
            candidate.side_price is not None for candidate in candidates
        ),
        "products_with_missing_prices": missing_count,
        "ambiguous_prices": len(ambiguous_rows or []),
        "ambiguous_price_details": ambiguous_rows or [],
        "repeated_product_codes": sum(
            count > 1 for count in code_counts.values()
        ),
        "affected_repeat_rows": sum(
            count - 1 for count in code_counts.values() if count > 1
        ),
        "rows_excluded_as_headings_or_non_products": 2,
        "invalid_or_incomplete_rows": len(invalid_rows or []),
        "invalid_row_details": invalid_rows or [],
        "all_section_values": sections,
        "valid_products": candidates,
    }


def test_review_groups_preserve_occurrences_and_classify_all_field_conflicts() -> None:
    wheel_2_candidates = [
        _candidate(
            vehicle_type="2-Wheeler",
            row_number=8,
            code="SIA-15",
            category="P",
            description="Part A | long text",
            model="Model 1",
            package="10 PC",
            list_price=12.5,
            side_price=10.25,
        ),
        _candidate(
            vehicle_type="2-Wheeler",
            row_number=9,
            code="SIA-15",
            category="UD",
            description="Part B",
            model="Model 2",
            package="15 PC",
            list_price=None,
            side_price=None,
        ),
    ]
    wheel_3_candidates = [
        _candidate(
            vehicle_type="3-Wheeler",
            row_number=5,
            code="SB-735",
            category="SB-735 L",
            description="Bracket",
            model="",
            package="5 SET",
            list_price=5.0,
        ),
        _candidate(
            vehicle_type="3-Wheeler",
            row_number=6,
            code="SB-735",
            category="SB-735 L",
            description="Bracket",
            model="",
            package="5 SET",
            list_price=5.0,
        ),
    ]
    reports = [
        _workbook_report(
            "2-Wheeler",
            "2W.xlsx",
            wheel_2_candidates,
            sections=["P", "UD"],
        ),
        _workbook_report(
            "3-Wheeler",
            "3W.xlsx",
            wheel_3_candidates,
            sections=["SB-735 L", "SB-735 R"],
        ),
    ]

    data = duplicate_report.build_review_data(reports)

    assert len(data["groups"]) == 2
    assert len(data["occurrences"]) == 4
    conflict_group = data["groups"][0]
    assert conflict_group["product_code"] == "SIA-15"
    assert conflict_group["occurrence_count"] == 2
    assert conflict_group["classification"] == "CATEGORY_OR_SECTION_CONFLICT"
    assert conflict_group["recommendation"] == "OWNER_CONFIRM_CATEGORY"
    assert conflict_group["differing_fields"] == [
        "category/section",
        "description",
        "vehicle model",
        "package quantity",
        "printed/list price",
        "revised/side price",
        "proposed final price",
        "price source",
    ]
    assert "PROPOSED_PRICE_CONFLICT" in conflict_group["issues"]
    assert "PRICE_AVAILABILITY_CONFLICT" in conflict_group["issues"]
    assert conflict_group["excel_rows"] == [8, 9]
    assert data["groups"][1]["classification"] == "POSSIBLE_EXACT_DUPLICATE"
    assert data["groups"][1]["recommendation"] == "OWNER_CONFIRM_DUPLICATE"
    assert len(data["missing_prices"]) == 1
    assert data["missing_prices"][0]["proposed_price"] is None
    assert data["categories"][0]["review_flag"] == "SUSPICIOUS LABEL - OWNER REVIEW"


def test_report_generation_writes_review_sheets_and_human_readable_markdown(
    tmp_path: Path,
) -> None:
    candidates = [
        _candidate(
            vehicle_type="3-Wheeler",
            row_number=21,
            code="SPRINGS",
            category="P",
            description="Spring",
            package="10 PC",
            list_price=None,
        ),
        _candidate(
            vehicle_type="3-Wheeler",
            row_number=22,
            code="SPRINGS",
            category="P",
            description="Spring",
            package="10 PC",
            list_price=None,
        ),
    ]
    invalid = {
        "worksheet_name": "Test Sheet",
        "row_number": 21,
        "vehicle_type": "3-Wheeler",
        "category_name": "P",
        "code": "SPRINGS",
        "description": None,
        "source_row": ["SPRINGS"],
        "reason": "description missing",
    }
    data = duplicate_report.build_review_data(
        [
            _workbook_report(
                "3-Wheeler",
                "3W.xlsx",
                candidates,
                sections=["P", "UD", "SB-735 L", "SB-735 R"],
                invalid_rows=[invalid],
            )
        ]
    )
    xlsx_path = tmp_path / "duplicate_product_code_review.xlsx"
    markdown_path = tmp_path / "duplicate_product_code_review.md"

    duplicate_report.write_excel_report(data, xlsx_path)
    duplicate_report.write_markdown_report(data, markdown_path)

    workbook = load_workbook(xlsx_path, read_only=False, data_only=True)
    assert workbook.sheetnames == [
        "Duplicate Groups",
        "Group Summary",
        "Missing Prices",
        "Invalid Rows",
        "Category Summary",
        "Overall Summary",
        "Ambiguous Prices",
    ]
    duplicates = workbook["Duplicate Groups"]
    assert duplicates.freeze_panes == "A2"
    assert duplicates.auto_filter.ref == duplicates.dimensions
    assert duplicates.max_row == 3
    assert duplicates["H2"].value == "Spring"
    summary = workbook["Overall Summary"]
    assert summary["N2"].value == 1
    assert summary["O2"].value == 2
    assert summary["P2"].value == 1
    assert workbook["Invalid Rows"]["H2"].value == "description missing"

    markdown = markdown_path.read_text(encoding="utf-8")
    assert "POSSIBLE_EXACT_DUPLICATE" in markdown
    assert "OWNER_CONFIRM_DUPLICATE" in markdown
    assert "suspicious section labels" in markdown.lower()
    assert "SB-735 L" in markdown
    assert "SB-735 R" in markdown
    assert "3W.xlsx row 21" in markdown
