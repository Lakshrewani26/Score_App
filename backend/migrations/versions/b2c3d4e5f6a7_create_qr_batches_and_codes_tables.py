"""Create qr_batches and qr_codes tables.

Revision ID: b2c3d4e5f6a7
Revises: e7b2c9d4f1a3
Create Date: 2026-10-26 14:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, None] = "e7b2c9d4f1a3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "qr_batches",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("batch_number", sa.String(length=60), nullable=False),
        sa.Column("qr_type", sa.String(length=50), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("points_rule_id", sa.Integer(), nullable=True),
        sa.Column("product_id", sa.Integer(), nullable=True),
        sa.Column("target_user_id", sa.Integer(), nullable=True),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=20), server_default="completed", nullable=False),
        sa.Column("metadata_json", sa.Text(), nullable=True),
        sa.Column("created_by", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "qr_type IN ('product', 'invoice', 'staff', 'partner')",
            name=op.f("ck_qr_batches_supported_qr_type"),
        ),
        sa.CheckConstraint(
            "status IN ('active', 'completed', 'cancelled')",
            name=op.f("ck_qr_batches_valid_qr_batch_status"),
        ),
        sa.CheckConstraint(
            "quantity > 0 AND quantity <= 1000",
            name=op.f("ck_qr_batches_valid_qr_batch_quantity"),
        ),
        sa.ForeignKeyConstraint(
            ["points_rule_id"],
            ["points_rules.id"],
            name=op.f("fk_qr_batches_points_rule_id_points_rules"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["products.id"],
            name=op.f("fk_qr_batches_product_id_products"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["target_user_id"],
            ["users.id"],
            name=op.f("fk_qr_batches_target_user_id_users"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["created_by"],
            ["users.id"],
            name=op.f("fk_qr_batches_created_by_users"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_qr_batches")),
    )
    op.create_index(
        "ix_qr_batches_batch_number",
        "qr_batches",
        ["batch_number"],
        unique=True,
    )
    op.create_index(
        "ix_qr_batches_qr_type",
        "qr_batches",
        ["qr_type"],
        unique=False,
    )
    op.create_index(
        "ix_qr_batches_status",
        "qr_batches",
        ["status"],
        unique=False,
    )

    op.create_table(
        "qr_codes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("batch_id", sa.Integer(), nullable=False),
        sa.Column("qr_type", sa.String(length=50), nullable=False),
        sa.Column("token", sa.String(length=64), nullable=False),
        sa.Column("code_data", sa.Text(), nullable=False),
        sa.Column("points_awarded", sa.Integer(), nullable=True),
        sa.Column("product_id", sa.Integer(), nullable=True),
        sa.Column("target_user_id", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(length=20), server_default="active", nullable=False),
        sa.Column("redeemed_by", sa.Integer(), nullable=True),
        sa.Column("redeemed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "qr_type IN ('product', 'invoice', 'staff', 'partner')",
            name=op.f("ck_qr_codes_supported_code_qr_type"),
        ),
        sa.CheckConstraint(
            "status IN ('active', 'redeemed', 'voided', 'expired')",
            name=op.f("ck_qr_codes_valid_qr_code_status"),
        ),
        sa.ForeignKeyConstraint(
            ["batch_id"],
            ["qr_batches.id"],
            name=op.f("fk_qr_codes_batch_id_qr_batches"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["products.id"],
            name=op.f("fk_qr_codes_product_id_products"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["target_user_id"],
            ["users.id"],
            name=op.f("fk_qr_codes_target_user_id_users"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["redeemed_by"],
            ["users.id"],
            name=op.f("fk_qr_codes_redeemed_by_users"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_qr_codes")),
    )
    op.create_index(
        "ix_qr_codes_token",
        "qr_codes",
        ["token"],
        unique=True,
    )
    op.create_index(
        "ix_qr_codes_batch_id",
        "qr_codes",
        ["batch_id"],
        unique=False,
    )
    op.create_index(
        "ix_qr_codes_qr_type",
        "qr_codes",
        ["qr_type"],
        unique=False,
    )
    op.create_index(
        "ix_qr_codes_status",
        "qr_codes",
        ["status"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_qr_codes_status", table_name="qr_codes")
    op.drop_index("ix_qr_codes_qr_type", table_name="qr_codes")
    op.drop_index("ix_qr_codes_batch_id", table_name="qr_codes")
    op.drop_index("ix_qr_codes_token", table_name="qr_codes")
    op.drop_table("qr_codes")

    op.drop_index("ix_qr_batches_status", table_name="qr_batches")
    op.drop_index("ix_qr_batches_qr_type", table_name="qr_batches")
    op.drop_index("ix_qr_batches_batch_number", table_name="qr_batches")
    op.drop_table("qr_batches")
