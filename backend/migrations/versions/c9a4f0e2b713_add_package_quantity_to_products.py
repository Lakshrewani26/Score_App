"""Add package quantity to products.

Revision ID: c9a4f0e2b713
Revises: b2c3d4e5f6a7
Create Date: 2026-10-27 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c9a4f0e2b713"
down_revision: Union[str, None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "products",
        sa.Column("package_quantity", sa.String(length=100), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("products", "package_quantity")
