"""Historical staff attribution and assignment lifecycle.

Revision ID: d5e6f7a8b9c0
Revises: c4d5e6f7a8b9
Create Date: 2026-11-15 21:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d5e6f7a8b9c0"
down_revision: Union[str, None] = "c4d5e6f7a8b9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    is_sqlite = bind is not None and getattr(bind.dialect, "name", "") == "sqlite"

    old_index_name = "uq_staff_partner_assignments_active_pair"
    new_index_name = "uq_staff_partner_assignments_active_partner"

    # =========================================================================
    # 1. Upgrade Pre-Validations (Run before ANY schema alteration)
    # =========================================================================
    if bind is not None:
        # A. Check for duplicate active assignments per partner.
        # Dialect-specific Boolean expression: PostgreSQL requires 'is_active IS TRUE',
        # while SQLite requires 'is_active = 1'.
        active_condition = "is_active = 1" if is_sqlite else "is_active IS TRUE"
        duplicate_check_sql = sa.text(
            f"SELECT partner_id, COUNT(*) AS active_cnt "
            f"FROM staff_partner_assignments "
            f"WHERE {active_condition} "
            f"GROUP BY partner_id "
            f"HAVING COUNT(*) > 1"
        )
        duplicates = bind.execute(duplicate_check_sql).fetchall()
        if duplicates:
            conflicting_partner_ids = [row[0] for row in duplicates]
            raise RuntimeError(
                f"Cannot apply migration: found conflicting duplicate active Staff assignments "
                f"for Partner IDs: {conflicting_partner_ids}. "
                "The migration must fail safely without arbitrarily choosing or deactivating records. "
                "Resolve conflicting records before proceeding."
            )

        # B. Inspect existing assignment indexes.
        # Verify the expected old index exists and the new index does not exist.
        inspector = sa.inspect(bind)
        existing_indexes = {
            idx["name"]
            for idx in inspector.get_indexes("staff_partner_assignments")
            if idx.get("name")
        }
        if old_index_name not in existing_indexes:
            raise RuntimeError(
                f"Cannot apply migration: expected index '{old_index_name}' was not found "
                f"on table 'staff_partner_assignments'. Existing indexes: {sorted(list(existing_indexes))}."
            )
        if new_index_name in existing_indexes:
            raise RuntimeError(
                f"Cannot apply migration: target index '{new_index_name}' already exists "
                f"on table 'staff_partner_assignments'."
            )

    # =========================================================================
    # 2. Schema Alterations (Execute only after all validations succeed)
    # =========================================================================

    # A. Modify staff_partner_assignments columns
    with op.batch_alter_table("staff_partner_assignments") as batch_op:
        batch_op.add_column(
            sa.Column("deactivated_at", sa.DateTime(timezone=True), nullable=True)
        )
        batch_op.add_column(
            sa.Column(
                "deactivated_by",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="RESTRICT"),
                nullable=True,
            )
        )

    # B. Swap unique partial index on staff_partner_assignments
    op.drop_index(
        old_index_name,
        table_name="staff_partner_assignments",
    )
    op.create_index(
        new_index_name,
        "staff_partner_assignments",
        ["partner_id"],
        unique=True,
        postgresql_where=sa.text("is_active IS TRUE"),
        sqlite_where=sa.text("is_active = 1"),
    )

    # C. Modify orders table:
    # - Add created_by_user_id, assigned_staff_id, staff_attribution_status
    # - Add check constraint and indexes
    with op.batch_alter_table("orders") as batch_op:
        batch_op.add_column(
            sa.Column(
                "created_by_user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            )
        )
        batch_op.add_column(
            sa.Column(
                "assigned_staff_id",
                sa.Integer(),
                sa.ForeignKey("staff_profiles.user_id", ondelete="RESTRICT"),
                nullable=True,
            )
        )
        batch_op.add_column(
            sa.Column(
                "staff_attribution_status",
                sa.String(length=30),
                nullable=False,
                server_default="historically_unattributed",
            )
        )
        batch_op.create_check_constraint(
            op.f("ck_orders_supported_staff_attribution_status"),
            "staff_attribution_status IN ('assigned', 'unassigned', 'historically_unattributed')",
        )
        batch_op.create_index(
            op.f("ix_orders_created_by_user_id"),
            ["created_by_user_id"],
        )
        batch_op.create_index(
            op.f("ix_orders_assigned_staff_id"),
            ["assigned_staff_id"],
        )
        batch_op.create_index(
            op.f("ix_orders_staff_attribution_status"),
            ["staff_attribution_status"],
        )

    # =========================================================================
    # 3. Conservative Historical Backfill
    # =========================================================================
    # A. Creator backfill:
    # An order is eligible only when it has exactly ONE qualifying initial creation event overall:
    # - Count ALL events where old_status IS NULL AND new_status = 'pending_approval' by order_id first.
    # - Do NOT filter events through a join to users before counting them.
    # - Keep only orders where COUNT(*) = 1.
    # - Retrieve that unique event's changed_by.
    # - Backfill created_by_user_id only if changed_by is non-null and references an existing user.
    # - Preserve the condition created_by_user_id IS NULL.
    #
    # B. Staff attribution backfill:
    # Because old assignment periods lack reliable deactivation timestamps and may have been reactivated,
    # historical orders remain:
    # assigned_staff_id = NULL
    # staff_attribution_status = 'historically_unattributed' (set via server_default).
    # Creator backfill and Staff attribution are separate decisions.
    if bind is not None:
        unique_initial_creators = bind.execute(sa.text("""
            SELECT osh.order_id, osh.changed_by
            FROM order_status_history osh
            JOIN users u ON u.id = osh.changed_by
            JOIN (
                SELECT osh_inner.order_id
                FROM order_status_history osh_inner
                WHERE osh_inner.old_status IS NULL
                  AND osh_inner.new_status = 'pending_approval'
                GROUP BY osh_inner.order_id
                HAVING COUNT(*) = 1
            ) single_events ON single_events.order_id = osh.order_id
            WHERE osh.old_status IS NULL
              AND osh.new_status = 'pending_approval'
              AND osh.changed_by IS NOT NULL
        """)).fetchall()

        for row in unique_initial_creators:
            order_id = row[0]
            changed_by = row[1]
            bind.execute(
                sa.text("""
                    UPDATE orders
                    SET created_by_user_id = :cb
                    WHERE id = :oid AND created_by_user_id IS NULL
                """),
                {"cb": changed_by, "oid": order_id},
            )


def downgrade() -> None:
    bind = op.get_bind()
    is_sqlite = bind is not None and getattr(bind.dialect, "name", "") == "sqlite"

    old_index_name = "uq_staff_partner_assignments_active_pair"
    new_index_name = "uq_staff_partner_assignments_active_partner"
    expected_constraint_name = "ck_orders_supported_staff_attribution_status"

    # =========================================================================
    # 1. Downgrade Pre-Validations (Run before ANY schema alteration)
    # A failed validation must not leave a partially downgraded schema.
    # =========================================================================
    if bind is not None:
        inspector = sa.inspect(bind)

        # A. Validate staff_partner_assignments indexes
        existing_spa_indexes = {
            idx["name"]
            for idx in inspector.get_indexes("staff_partner_assignments")
            if idx.get("name")
        }
        if new_index_name not in existing_spa_indexes:
            raise RuntimeError(
                f"Cannot downgrade migration: expected index '{new_index_name}' was not found "
                f"on table 'staff_partner_assignments'. Existing indexes: {sorted(list(existing_spa_indexes))}."
            )
        if old_index_name in existing_spa_indexes:
            raise RuntimeError(
                f"Cannot downgrade migration: previous index '{old_index_name}' already exists "
                f"on table 'staff_partner_assignments'."
            )

        # B. Validate staff_partner_assignments columns
        existing_spa_cols = {col["name"] for col in inspector.get_columns("staff_partner_assignments")}
        for col_name in ["deactivated_at", "deactivated_by"]:
            if col_name not in existing_spa_cols:
                raise RuntimeError(
                    f"Cannot downgrade migration: expected column '{col_name}' was not found "
                    f"on table 'staff_partner_assignments'."
                )

        # C. Validate orders columns
        existing_order_cols = {col["name"] for col in inspector.get_columns("orders")}
        for col_name in ["created_by_user_id", "assigned_staff_id", "staff_attribution_status"]:
            if col_name not in existing_order_cols:
                raise RuntimeError(
                    f"Cannot downgrade migration: expected column '{col_name}' was not found "
                    f"on table 'orders'."
                )

        # D. Validate orders indexes
        existing_order_indexes = {
            idx["name"]
            for idx in inspector.get_indexes("orders")
            if idx.get("name")
        }
        for idx_name in [
            "ix_orders_created_by_user_id",
            "ix_orders_assigned_staff_id",
            "ix_orders_staff_attribution_status",
        ]:
            if idx_name not in existing_order_indexes:
                raise RuntimeError(
                    f"Cannot downgrade migration: expected index '{idx_name}' was not found "
                    f"on table 'orders'."
                )

        # E. Validate orders check constraint strictly
        # If the expected check constraint cannot be verified, fail before making schema changes.
        existing_order_checks = {
            c["name"]
            for c in inspector.get_check_constraints("orders")
            if c.get("name")
        }
        # On SQLite, also inspect sqlite_master DDL as a secondary verification
        if is_sqlite and expected_constraint_name not in existing_order_checks:
            table_sql_row = bind.execute(
                sa.text("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'orders'")
            ).fetchone()
            if table_sql_row and table_sql_row[0] and expected_constraint_name in table_sql_row[0]:
                existing_order_checks.add(expected_constraint_name)

        if expected_constraint_name not in existing_order_checks:
            raise RuntimeError(
                f"Cannot downgrade migration: expected check constraint '{expected_constraint_name}' was not found "
                f"on table 'orders'. Existing check constraints: {sorted(list(existing_order_checks))}."
            )

    # =========================================================================
    # 2. Downgrade Operations (Execute only after all validations succeed)
    # =========================================================================

    # A. Drop orders modifications
    # Use batch_alter_table to drop check constraint before dropping staff_attribution_status,
    # including on SQLite. The constraint name matches the name created during upgrade.
    with op.batch_alter_table("orders") as batch_op:
        batch_op.drop_index(op.f("ix_orders_staff_attribution_status"))
        batch_op.drop_index(op.f("ix_orders_assigned_staff_id"))
        batch_op.drop_index(op.f("ix_orders_created_by_user_id"))
        batch_op.drop_constraint(
            op.f(expected_constraint_name),
            type_="check",
        )
        batch_op.drop_column("staff_attribution_status")
        batch_op.drop_column("assigned_staff_id")
        batch_op.drop_column("created_by_user_id")

    # B. Swap unique partial index on staff_partner_assignments back to active-pair index
    op.drop_index(
        new_index_name,
        table_name="staff_partner_assignments",
    )
    op.create_index(
        old_index_name,
        "staff_partner_assignments",
        ["staff_id", "partner_id"],
        unique=True,
        postgresql_where=sa.text("is_active IS TRUE"),
        sqlite_where=sa.text("is_active = 1"),
    )

    # C. Drop staff_partner_assignments column additions
    with op.batch_alter_table("staff_partner_assignments") as batch_op:
        batch_op.drop_column("deactivated_by")
        batch_op.drop_column("deactivated_at")
