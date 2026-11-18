"""Add list_price to products and mrp, list_price snapshots to order_items.

Revision ID: e6f7a8b9c0d1
Revises: d5e6f7a8b9c0
Create Date: 2026-11-17 12:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e6f7a8b9c0d1"
down_revision: Union[str, None] = "d5e6f7a8b9c0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add list_price to products
    with op.batch_alter_table("products") as batch_op:
        batch_op.add_column(
            sa.Column("list_price", sa.Numeric(precision=12, scale=2), nullable=True)
        )
        batch_op.create_check_constraint(
            "nonnegative_list_price",
            "list_price IS NULL OR list_price >= 0",
        )

    # 2. Add mrp and list_price snapshots to order_items
    with op.batch_alter_table("order_items") as batch_op:
        batch_op.add_column(
            sa.Column("mrp", sa.Numeric(precision=12, scale=2), nullable=True)
        )
        batch_op.add_column(
            sa.Column("list_price", sa.Numeric(precision=12, scale=2), nullable=True)
        )
        batch_op.create_check_constraint(
            "nonnegative_item_mrp",
            "mrp IS NULL OR mrp >= 0",
        )
        batch_op.create_check_constraint(
            "nonnegative_item_list_price",
            "list_price IS NULL OR list_price >= 0",
        )

    # 3. Safe backfill for historical order_items.mrp
    # Uses historical original_price snapshot (which represented catalog MRP before discounts).
    # Only fills eligible rows where mrp IS NULL and original_price IS NOT NULL.
    # Does not use unit_price as fallback (unit_price may represent discounted price).
    # Does not overwrite non-NULL snapshots, and does not infer or fabricate list_price.
    op.execute(
        sa.text(
            "UPDATE order_items "
            "SET mrp = original_price "
            "WHERE mrp IS NULL "
            "  AND original_price IS NOT NULL"
        )
    )


def downgrade() -> None:
    # 1. Revert order_items additions
    with op.batch_alter_table("order_items") as batch_op:
        batch_op.drop_constraint("nonnegative_item_list_price", type_="check")
        batch_op.drop_constraint("nonnegative_item_mrp", type_="check")
        batch_op.drop_column("list_price")
        batch_op.drop_column("mrp")

    # 2. Revert products additions
    with op.batch_alter_table("products") as batch_op:
        batch_op.drop_constraint("nonnegative_list_price", type_="check")
        batch_op.drop_column("list_price")
