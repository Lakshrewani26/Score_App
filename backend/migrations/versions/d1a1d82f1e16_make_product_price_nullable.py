"""Make product price nullable and support repeatable source-row imports.

Revision ID: d1a1d82f1e16
Revises: 56ecec28acb3
Create Date: 2026-10-19 01:25:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d1a1d82f1e16"
down_revision: Union[str, None] = "56ecec28acb3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "products",
        "price",
        existing_type=sa.Numeric(precision=12, scale=2),
        nullable=True,
    )
    op.drop_constraint("uq_products_product_code", "products", type_="unique")
    op.create_table(
        "catalogue_import_audit",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("workbook_name", sa.String(length=120), nullable=False),
        sa.Column("worksheet_name", sa.String(length=120), nullable=False),
        sa.Column("excel_row_number", sa.Integer(), nullable=False),
        sa.Column("product_code", sa.String(length=50), nullable=False),
        sa.Column("product_name", sa.String(length=200), nullable=False),
        sa.Column("source_row_fingerprint", sa.String(length=128), nullable=False, unique=True),
        sa.Column("imported_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_catalogue_import_audit")),
    )
    op.create_index(
        "ix_catalogue_import_audit_workbook_worksheet_row",
        "catalogue_import_audit",
        ["workbook_name", "worksheet_name", "excel_row_number"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_catalogue_import_audit_workbook_worksheet_row", table_name="catalogue_import_audit")
    op.drop_table("catalogue_import_audit")
    op.alter_column(
        "products",
        "price",
        existing_type=sa.Numeric(precision=12, scale=2),
        nullable=False,
    )
    op.create_unique_constraint(
        "uq_products_product_code",
        "products",
        ["product_code"],
    )
