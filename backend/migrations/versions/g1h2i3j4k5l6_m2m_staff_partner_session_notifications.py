"""M2M staff-partner assignments, session tokens, and notifications table.

Changes:
1. Drop old unique partial index uq_staff_partner_assignments_active_partner (partner_id only).
2. Add new unique partial index uq_staff_partner_assignments_active_pair (staff_id, partner_id).
   This enables many-to-many: one partner can have multiple staff, one staff can have multiple partners.
   Duplicate active (staff_id, partner_id) pairs are still prevented.
3. Add session_token column to users table for single-active-session enforcement.
4. Create notifications table for in-app order notifications with unique constraint
   uq_notifications_user_order on (user_id, order_id).

Downgrade Safety Strategy:
- Pre-validation: Before dropping tables, columns, or indexes, check whether
  any partner has multiple active staff assignments.
  - If conflicts exist, abort immediately with an error detailing the partner(s).
  - In both PostgreSQL and SQLite (where DDL can auto-commit transactions), this
    guarantees that a failed downgrade leaves the schema and data completely untouched
    (no dropped tables, no lost columns, no lost assignment data).
- To execute downgrade in an environment with multiple active staff per partner, operators
  must first resolve the conflict (deactivating extra staff assignments via application UI/API)
  before running `alembic downgrade`.
- When pre-validation passes:
  1. Drop notifications table and its indexes.
  2. Remove session_token index and column from users table.
  3. Revert staff_partner_assignments index from pair-level to partner-level.

Revision ID: g1h2i3j4k5l6
Revises: e6f7a8b9c0d1
Create Date: 2026-11-24 10:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "g1h2i3j4k5l6"
down_revision: Union[str, None] = "e6f7a8b9c0d1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _is_postgres() -> bool:
    bind = op.get_bind()
    return bind is not None and getattr(bind.dialect, "name", "") == "postgresql"


def upgrade() -> None:
    is_pg = _is_postgres()

    # -------------------------------------------------------------------------
    # 1. Replace the old one-staff-per-partner partial index with an M2M index
    # -------------------------------------------------------------------------
    op.drop_index(
        "uq_staff_partner_assignments_active_partner",
        table_name="staff_partner_assignments",
    )
    op.create_index(
        "uq_staff_partner_assignments_active_pair",
        "staff_partner_assignments",
        ["staff_id", "partner_id"],
        unique=True,
        postgresql_where=sa.text("is_active IS TRUE"),
        sqlite_where=sa.text("is_active = 1"),
    )

    # -------------------------------------------------------------------------
    # 2. Add session_token column to users table
    # -------------------------------------------------------------------------
    op.add_column(
        "users",
        sa.Column("session_token", sa.String(64), nullable=True),
    )
    op.create_index(
        "ix_users_session_token",
        "users",
        ["session_token"],
        unique=False,
    )

    # -------------------------------------------------------------------------
    # 3. Create notifications table
    # -------------------------------------------------------------------------
    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("type", sa.String(50), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column(
            "order_id",
            sa.Integer(),
            sa.ForeignKey("orders.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "is_read",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false") if is_pg else sa.text("0"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("user_id", "order_id", name="uq_notifications_user_order"),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])
    op.create_index("ix_notifications_is_read", "notifications", ["is_read"])
    op.create_index("ix_notifications_created_at", "notifications", ["created_at"])


def downgrade() -> None:
    """Downgrade schema safely."""
    bind = op.get_bind()
    is_pg = _is_postgres()

    # =========================================================================
    # 1. Downgrade Pre-Validation (Run before ANY schema alteration)
    # Ensure restoring 1:1 active partner index won't fail due to duplicate active staff.
    # Aborting here ensures that SQLite (which may auto-commit DDL) and PostgreSQL
    # are never left in a partially downgraded state.
    # =========================================================================
    if bind is not None:
        where_cond = "is_active IS TRUE" if is_pg else "is_active = 1"
        dup_rows = bind.execute(
            sa.text(
                f"SELECT partner_id, COUNT(*) AS cnt "
                f"FROM staff_partner_assignments "
                f"WHERE {where_cond} "
                f"GROUP BY partner_id "
                f"HAVING COUNT(*) > 1"
            )
        ).fetchall()
        if dup_rows:
            conflicted_partners = [str(row[0]) for row in dup_rows]
            raise RuntimeError(
                f"Cannot downgrade migration g1h2i3j4k5l6: multiple active staff assignments exist for "
                f"partner(s) {', '.join(conflicted_partners)}. Deactivate duplicate active staff "
                f"assignments before running alembic downgrade."
            )

    # =========================================================================
    # 2. Drop notifications table and indexes
    # =========================================================================
    op.drop_index("ix_notifications_created_at", table_name="notifications")
    op.drop_index("ix_notifications_is_read", table_name="notifications")
    op.drop_index("ix_notifications_user_id", table_name="notifications")
    op.drop_table("notifications")

    # =========================================================================
    # 3. Remove session_token column and index
    # =========================================================================
    op.drop_index("ix_users_session_token", table_name="users")
    op.drop_column("users", "session_token")

    # =========================================================================
    # 4. Restore 1:1 active assignment partial index
    # =========================================================================
    op.drop_index(
        "uq_staff_partner_assignments_active_pair",
        table_name="staff_partner_assignments",
    )
    op.create_index(
        "uq_staff_partner_assignments_active_partner",
        "staff_partner_assignments",
        ["partner_id"],
        unique=True,
        postgresql_where=sa.text("is_active IS TRUE"),
        sqlite_where=sa.text("is_active = 1"),
    )
