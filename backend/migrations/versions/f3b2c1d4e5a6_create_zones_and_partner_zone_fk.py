"""Create zones table and add zone_id to partner_profiles.

Revision ID: f3b2c1d4e5a6
Revises: c9a4f0e2b713
Create Date: 2026-11-06 20:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f3b2c1d4e5a6"
down_revision: Union[str, None] = "c9a4f0e2b713"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create zones table
    op.create_table(
        "zones",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )

    # 2. Add zone_id column and foreign key to partner_profiles
    op.add_column(
        "partner_profiles",
        sa.Column("zone_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_partner_profiles_zone_id_zones",
        "partner_profiles",
        "zones",
        ["zone_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_partner_profiles_zone_id_zones", "partner_profiles", type_="foreignkey")
    op.drop_column("partner_profiles", "zone_id")
    op.drop_table("zones")
