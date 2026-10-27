from __future__ import annotations

from collections.abc import Generator
from contextlib import contextmanager
from decimal import Decimal
from pathlib import Path
import sys

import sqlalchemy

from app.core.config import settings
from scripts import catalogue_import


class FakeSheet:
    max_row = 2

    def iter_rows(self, *, values_only: bool):
        assert values_only
        return iter(
            [
                ("ABC-01", "Brake lever", None, "10 PC"),
                ("ABC-01", "Brake cable", None, "15 PC"),
            ]
        )


class FakeWorkbook:
    sheetnames = ["Parts"]

    def __getitem__(self, sheet_name: str) -> FakeSheet:
        assert sheet_name == "Parts"
        return FakeSheet()


def fake_load_workbook(
    path: Path, *, read_only: bool, data_only: bool
) -> FakeWorkbook:
    del path, read_only, data_only
    return FakeWorkbook()


class FakeResult:
    def __init__(self, values: list[str] | None = None) -> None:
        self.values = values or []

    def scalars(self) -> FakeResult:
        return self

    def all(self) -> list[str]:
        return self.values

    def scalar_one_or_none(self) -> int:
        return 1

    def scalar_one(self) -> int:
        return 1


class RecordingConnection:
    def __init__(self) -> None:
        self.product_statement = ""
        self.products: list[dict[str, object]] = []
        self.audits: list[dict[str, object]] = []

    def execute(
        self, statement: object, parameters: dict[str, object] | None = None
    ) -> FakeResult:
        sql = str(statement)
        if "SELECT source_row_fingerprint" in sql:
            return FakeResult(
                [str(row["source_row_fingerprint"]) for row in self.audits]
            )
        if "SELECT id FROM product_categories" in sql:
            return FakeResult()
        if "INSERT INTO products" in sql:
            self.product_statement = sql
            assert parameters is not None
            self.products.append(parameters)
            return FakeResult()
        if "SELECT id FROM products" in sql:
            return FakeResult()
        if "INSERT INTO catalogue_import_audit" in sql:
            assert parameters is not None
            self.audits.append(parameters)
            return FakeResult()
        raise AssertionError(f"Unexpected SQL statement: {sql}")


class RecordingEngine:
    def __init__(self, connection: RecordingConnection) -> None:
        self.connection = connection

    @contextmanager
    def begin(self) -> Generator[RecordingConnection, None, None]:
        yield self.connection


def test_missing_prices_are_counted_once_and_repeated_codes_are_reported(
    tmp_path: Path, monkeypatch, capsys
) -> None:
    workbook_path = tmp_path / "catalogue.xlsx"
    workbook_path.touch()
    monkeypatch.setattr(catalogue_import, "DATA_DIR", tmp_path)
    monkeypatch.setattr(
        catalogue_import,
        "load_workbook",
        fake_load_workbook,
    )

    report = catalogue_import._build_report_for_workbook(
        "2-Wheeler", workbook_path.name, "Parts"
    )

    assert report["products_with_missing_prices"] == 2
    assert report["valid_product_candidates"] == 2
    assert [candidate.package_quantity for candidate in report["valid_products"]] == [
        "10 PC",
        "15 PC",
    ]
    assert report["repeated_product_codes"] == 1
    assert report["repeated_product_code_values"] == ["ABC-01"]
    assert report["affected_repeat_rows"] == 1

    catalogue_import._render_report(report)

    assert "Repeated product codes for review: ABC-01" in capsys.readouterr().out


def test_dry_run_does_not_create_a_database_engine(
    tmp_path: Path, monkeypatch
) -> None:
    workbook_path = tmp_path / "catalogue.xlsx"
    workbook_path.touch()
    monkeypatch.setattr(sys, "argv", ["catalogue_import.py", "--dry-run"])
    monkeypatch.setattr(catalogue_import, "DATA_DIR", tmp_path)
    monkeypatch.setattr(
        catalogue_import,
        "WORKBOOK_SPECS",
        {"2-Wheeler": {"filename": workbook_path.name, "sheet_name": "Parts"}},
    )
    monkeypatch.setattr(catalogue_import, "load_workbook", fake_load_workbook)

    def fail_if_database_engine_is_created(
        database_url: str, *, pool_pre_ping: bool
    ) -> None:
        del database_url, pool_pre_ping
        raise AssertionError("Dry-run must not create a database engine")

    monkeypatch.setattr(
        sqlalchemy, "create_engine", fail_if_database_engine_is_created
    )

    catalogue_import.main()


def test_import_sql_writes_package_quantity_and_preserves_repeatable_candidates(
    monkeypatch,
) -> None:
    monkeypatch.setattr(settings, "database_url", "test-local-only")
    monkeypatch.setattr(
        catalogue_import,
        "WORKBOOK_SPECS",
        {"2-Wheeler": {"filename": "catalogue.xlsx", "sheet_name": "Parts"}},
    )
    candidates = [
        catalogue_import.ProductCandidate(
            workbook="2-Wheeler",
            sheet_name="Parts",
            row_number=1,
            code="ABC-01",
            category_name="Parts",
            description="Brake lever",
            vehicle_type=None,
            list_price=None,
            side_price=None,
            package_quantity="10 PC",
            source_row=["ABC-01", "Brake lever", "10 PC"],
        ),
        catalogue_import.ProductCandidate(
            workbook="2-Wheeler",
            sheet_name="Parts",
            row_number=2,
            code="ABC-01",
            category_name="Parts",
            description="Brake cable",
            vehicle_type=None,
            list_price=Decimal("20.00"),
            side_price=None,
            package_quantity="15 PC",
            source_row=["ABC-01", "Brake cable", "20.00", "15 PC"],
        ),
        catalogue_import.ProductCandidate(
            workbook="2-Wheeler",
            sheet_name="Parts",
            row_number=3,
            code="ABC-01",
            category_name="Parts",
            description="Brake pad set",
            vehicle_type=None,
            list_price=Decimal("25.00"),
            side_price=Decimal("22.50"),
            package_quantity="5 SET",
            source_row=["ABC-01", "Brake pad set", "25.00", "22.50", "5 SET"],
        ),
    ]

    def fake_build_report(
        workbook_name: str, filename: str, sheet_name: str
    ) -> dict[str, list[catalogue_import.ProductCandidate]]:
        del workbook_name, filename, sheet_name
        return {"valid_products": candidates}

    connection = RecordingConnection()

    def fake_create_engine(
        database_url: str, *, pool_pre_ping: bool
    ) -> RecordingEngine:
        del database_url, pool_pre_ping
        return RecordingEngine(connection)

    monkeypatch.setattr(sqlalchemy, "create_engine", fake_create_engine)
    monkeypatch.setattr(
        catalogue_import,
        "_build_report_for_workbook",
        fake_build_report,
    )

    catalogue_import._import_workbooks()

    assert "package_quantity" in connection.product_statement
    assert [row["product_code"] for row in connection.products] == [
        "ABC-01",
        "ABC-01",
        "ABC-01",
    ]
    assert [row["package_quantity"] for row in connection.products] == [
        "10 PC",
        "15 PC",
        "5 SET",
    ]
    assert [row["price"] for row in connection.products] == [
        None,
        Decimal("20.00"),
        Decimal("22.50"),
    ]
    assert len(connection.audits) == 3
    assert len(
        {row["source_row_fingerprint"] for row in connection.audits}
    ) == len(connection.audits)

    catalogue_import._import_workbooks()

    assert len(connection.products) == 3
    assert len(connection.audits) == 3
