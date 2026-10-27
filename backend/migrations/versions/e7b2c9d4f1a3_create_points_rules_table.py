"""Create points_rules table.

Revision ID: e7b2c9d4f1a3
Revises: d1a1d82f1e16
Create Date: 2026-10-26 12:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e7b2c9d4f1a3"
down_revision: Union[str, None] = "d1a1d82f1e16"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "points_rules",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("rule_name", sa.String(length=120), nullable=False),
        sa.Column("rule_description", sa.Text(), nullable=True),
        sa.Column("category", sa.String(length=50), nullable=False),
        sa.Column("points_awarded", sa.Integer(), nullable=True),
        sa.Column("points_required", sa.Integer(), nullable=True),
        sa.Column("min_transaction_value", sa.Numeric(precision=12, scale=2), nullable=True),
        sa.Column("max_transaction_value", sa.Numeric(precision=12, scale=2), nullable=True),
        sa.Column("effective_from", sa.DateTime(timezone=True), nullable=True),
        sa.Column("effective_to", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("created_by", sa.Integer(), nullable=True),
        sa.Column("updated_by", sa.Integer(), nullable=True),
        sa.CheckConstraint(
            "category IN ('product_qr_scan', 'invoice_qr_scan', 'redemption', 'customer_to_partner_transfer', 'partner_to_staff_transfer')",
            name=op.f("ck_points_rules_supported_rule_category"),
        ),
        sa.CheckConstraint(
            "points_awarded IS NULL OR points_awarded >= 0",
            name=op.f("ck_points_rules_nonnegative_points_awarded"),
        ),
        sa.CheckConstraint(
            "points_required IS NULL OR points_required >= 0",
            name=op.f("ck_points_rules_nonnegative_points_required"),
        ),
        sa.CheckConstraint(
            "min_transaction_value IS NULL OR min_transaction_value >= 0",
            name=op.f("ck_points_rules_nonnegative_min_transaction_value"),
        ),
        sa.CheckConstraint(
            "max_transaction_value IS NULL OR max_transaction_value >= 0",
            name=op.f("ck_points_rules_nonnegative_max_transaction_value"),
        ),
        sa.ForeignKeyConstraint(
            ["created_by"],
            ["users.id"],
            name=op.f("fk_points_rules_created_by_users"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["updated_by"],
            ["users.id"],
            name=op.f("fk_points_rules_updated_by_users"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_points_rules")),
    )
    op.create_index(
        "ix_points_rules_category",
        "points_rules",
        ["category"],
        unique=False,
    )
    op.create_index(
        "ix_points_rules_is_active",
        "points_rules",
        ["is_active"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_points_rules_is_active", table_name="points_rules")
    op.drop_index("ix_points_rules_category", table_name="points_rules")
    op.drop_table("points_rules")
