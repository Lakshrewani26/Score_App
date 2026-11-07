"""Features G and H: Loyalty point rules versioning, point transactions, and partner discounts.

Revision ID: a1b2c3d4e5f6
Revises: f3b2c1d4e5a6
Create Date: 2026-11-07 01:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "f3b2c1d4e5a6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Update points_rules table
    bind = op.get_bind()
    is_sqlite = bind is not None and getattr(bind.dialect, "name", "") == "sqlite"
    should_drop_category_constraint = True
    if is_sqlite:
        insp = sa.inspect(bind)
        existing_checks = {c["name"] for c in insp.get_check_constraints("points_rules")}
        should_drop_category_constraint = "ck_points_rules_supported_rule_category" in existing_checks

    with op.batch_alter_table("points_rules") as batch_op:
        batch_op.add_column(sa.Column("conversion_rate", sa.Numeric(10, 4), nullable=True))
        batch_op.add_column(sa.Column("point_value", sa.Numeric(10, 4), nullable=True))
        batch_op.add_column(sa.Column("version", sa.Integer(), nullable=False, server_default="1"))
        batch_op.add_column(sa.Column("parent_rule_id", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("is_current", sa.Boolean(), nullable=False, server_default=sa.text("true")))
        batch_op.create_foreign_key(
            "fk_points_rules_parent_rule_id_points_rules",
            "points_rules",
            ["parent_rule_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch_op.create_index("ix_points_rules_parent_rule_id", ["parent_rule_id"])
        batch_op.create_index("ix_points_rules_is_current", ["is_current"])
        batch_op.create_unique_constraint(
            "uq_points_rules_parent_rule_id_version",
            ["parent_rule_id", "version"],
        )
        # Drop old check constraint on category that lacked customer_qr_scan and partner_qr_scan
        if should_drop_category_constraint:
            batch_op.drop_constraint("ck_points_rules_supported_rule_category", type_="check")
        # Recreate check constraint with all supported categories
        batch_op.create_check_constraint(
            "ck_points_rules_supported_rule_category",
            "category IN ('customer_qr_scan', 'partner_qr_scan', 'product_qr_scan', "
            "'invoice_qr_scan', 'redemption', 'customer_to_partner_transfer', "
            "'partner_to_staff_transfer')",
        )
        batch_op.create_check_constraint(
            "ck_points_rules_nonnegative_conversion_rate",
            "conversion_rate IS NULL OR conversion_rate >= 0",
        )
        batch_op.create_check_constraint(
            "ck_points_rules_nonnegative_point_value",
            "point_value IS NULL OR point_value >= 0",
        )
        batch_op.create_check_constraint(
            "ck_points_rules_positive_rule_version",
            "version >= 1",
        )

    # 2. Create point_transactions table
    op.create_table(
        "point_transactions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("qr_code_id", sa.Integer(), nullable=False),
        sa.Column("qr_token", sa.String(length=64), nullable=False),
        sa.Column("points_rule_id", sa.Integer(), nullable=False),
        sa.Column("points_awarded", sa.Integer(), nullable=False),
        sa.Column("qr_type", sa.String(length=50), nullable=False),
        sa.Column("transaction_type", sa.String(length=50), nullable=False, server_default="qr_scan"),
        sa.Column("idempotency_key", sa.String(length=128), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("points_awarded >= 0", name="nonnegative_points_awarded_trans"),
        sa.ForeignKeyConstraint(
            ["points_rule_id"],
            ["points_rules.id"],
            name=op.f("fk_point_transactions_points_rule_id_points_rules"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["qr_code_id"],
            ["qr_codes.id"],
            name=op.f("fk_point_transactions_qr_code_id_qr_codes"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_point_transactions_user_id_users"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_point_transactions")),
        sa.UniqueConstraint("qr_code_id", name=op.f("uq_point_transactions_qr_code_id")),
    )
    op.create_index("ix_point_transactions_user_id", "point_transactions", ["user_id"])
    op.create_index("ix_point_transactions_qr_code_id", "point_transactions", ["qr_code_id"])
    op.create_index("ix_point_transactions_qr_token", "point_transactions", ["qr_token"])
    op.create_index("ix_point_transactions_points_rule_id", "point_transactions", ["points_rule_id"])

    # 3. Update partner_profiles table
    with op.batch_alter_table("partner_profiles") as batch_op:
        batch_op.add_column(
            sa.Column("discount_percentage", sa.Numeric(5, 2), nullable=False, server_default="0.00")
        )

    # 4. Update orders table
    with op.batch_alter_table("orders") as batch_op:
        batch_op.add_column(sa.Column("subtotal_before_discount", sa.Numeric(12, 2), nullable=True))
        batch_op.add_column(sa.Column("discount_percentage", sa.Numeric(5, 2), nullable=True))
        batch_op.add_column(sa.Column("total_discount", sa.Numeric(12, 2), nullable=True))
        batch_op.add_column(sa.Column("final_total", sa.Numeric(12, 2), nullable=True))

    # 5. Update order_items table
    with op.batch_alter_table("order_items") as batch_op:
        batch_op.add_column(sa.Column("original_price", sa.Numeric(12, 2), nullable=True))
        batch_op.add_column(sa.Column("discount_percentage", sa.Numeric(5, 2), nullable=True))
        batch_op.add_column(sa.Column("discount_amount", sa.Numeric(12, 2), nullable=True))
        batch_op.add_column(sa.Column("discounted_price", sa.Numeric(12, 2), nullable=True))


def downgrade() -> None:
    # -------------------------------------------------------------------------
    # Safety Check: Non-destructive Downgrade Verification
    # -------------------------------------------------------------------------
    # Downgrade restores the original 5-category constraint from migration e7b2c9d4f1a3:
    #   category IN ('product_qr_scan', 'invoice_qr_scan', 'redemption',
    #                'customer_to_partner_transfer', 'partner_to_staff_transfer')
    # and drops the point_transactions table.
    #
    # If the database contains any points rules using the new Feature G categories
    # ('customer_qr_scan', 'partner_qr_scan') or any transactions in 'point_transactions',
    # a downgrade cannot safely proceed without orphaning or destroying loyalty history.
    #
    # To prevent silent data loss or foreign-key corruption, we explicitly check for
    # existing data in online mode. If detected, downgrade aborts with a clear RuntimeError
    # instructing the administrator to safely archive or migrate records first.
    # -------------------------------------------------------------------------
    context = op.get_context()
    if not getattr(context, "as_sql", False):
        bind = op.get_bind()
        if bind is not None and getattr(bind.dialect, "name", "") != "mock":
            insp = sa.inspect(bind)
            table_names = set(insp.get_table_names())
            if "point_transactions" in table_names:
                pt_count = bind.execute(sa.text("SELECT COUNT(1) FROM point_transactions")).scalar()
                if pt_count and pt_count > 0:
                    raise RuntimeError(
                        f"Cannot safely downgrade migration 'a1b2c3d4e5f6': found {pt_count} point transaction(s) "
                        "in 'point_transactions'. Dropping this table would destroy loyalty audit history. "
                        "To proceed with downgrade, manually archive or export point transactions first."
                    )
            if "points_rules" in table_names:
                cat_count = bind.execute(
                    sa.text(
                        "SELECT COUNT(1) FROM points_rules "
                        "WHERE category IN ('customer_qr_scan', 'partner_qr_scan')"
                    )
                ).scalar()
                if cat_count and cat_count > 0:
                    raise RuntimeError(
                        f"Cannot safely downgrade migration 'a1b2c3d4e5f6': found {cat_count} loyalty rule(s) "
                        "using Feature G categories ('customer_qr_scan', 'partner_qr_scan'). "
                        "Reinstating the original 5-category check constraint would fail or require destructive "
                        "data deletion that would orphan or corrupt historical point transactions. "
                        "To proceed with downgrade, manually review, migrate, or archive these rules first."
                    )

    with op.batch_alter_table("order_items") as batch_op:
        batch_op.drop_column("discounted_price")
        batch_op.drop_column("discount_amount")
        batch_op.drop_column("discount_percentage")
        batch_op.drop_column("original_price")

    with op.batch_alter_table("orders") as batch_op:
        batch_op.drop_column("final_total")
        batch_op.drop_column("total_discount")
        batch_op.drop_column("discount_percentage")
        batch_op.drop_column("subtotal_before_discount")

    with op.batch_alter_table("partner_profiles") as batch_op:
        batch_op.drop_column("discount_percentage")

    op.drop_index("ix_point_transactions_points_rule_id", table_name="point_transactions")
    op.drop_index("ix_point_transactions_qr_token", table_name="point_transactions")
    op.drop_index("ix_point_transactions_qr_code_id", table_name="point_transactions")
    op.drop_index("ix_point_transactions_user_id", table_name="point_transactions")
    op.drop_table("point_transactions")

    bind = op.get_bind()
    is_sqlite = bind is not None and getattr(bind.dialect, "name", "") == "sqlite"
    existing_checks = set()
    if is_sqlite:
        insp = sa.inspect(bind)
        existing_checks = {c["name"] for c in insp.get_check_constraints("points_rules")}

    with op.batch_alter_table("points_rules") as batch_op:
        if not is_sqlite or "ck_points_rules_positive_rule_version" in existing_checks:
            batch_op.drop_constraint("ck_points_rules_positive_rule_version", type_="check")
        if not is_sqlite or "ck_points_rules_nonnegative_point_value" in existing_checks:
            batch_op.drop_constraint("ck_points_rules_nonnegative_point_value", type_="check")
        if not is_sqlite or "ck_points_rules_nonnegative_conversion_rate" in existing_checks:
            batch_op.drop_constraint("ck_points_rules_nonnegative_conversion_rate", type_="check")
        if not is_sqlite or "ck_points_rules_supported_rule_category" in existing_checks:
            batch_op.drop_constraint("ck_points_rules_supported_rule_category", type_="check")
        # Restore the original check constraint from migration e7b2c9d4f1a3
        batch_op.create_check_constraint(
            "ck_points_rules_supported_rule_category",
            "category IN ('product_qr_scan', 'invoice_qr_scan', 'redemption', "
            "'customer_to_partner_transfer', 'partner_to_staff_transfer')",
        )
        batch_op.drop_constraint("uq_points_rules_parent_rule_id_version", type_="unique")
        batch_op.drop_index("ix_points_rules_is_current")
        batch_op.drop_column("is_current")
        batch_op.drop_index("ix_points_rules_parent_rule_id")
        batch_op.drop_constraint("fk_points_rules_parent_rule_id_points_rules", type_="foreignkey")
        batch_op.drop_column("parent_rule_id")
        batch_op.drop_column("version")
        batch_op.drop_column("point_value")
        batch_op.drop_column("conversion_rate")
