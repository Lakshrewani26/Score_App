"""Create point_transfers table.

Revision ID: b3c4d5e6f7a8
Revises: a1b2c3d4e5f6
Create Date: 2026-11-09 20:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b3c4d5e6f7a8"
down_revision: Union[str, None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "point_transfers",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("sender_id", sa.Integer(), nullable=False),
        sa.Column("recipient_id", sa.Integer(), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("points_rule_id", sa.Integer(), nullable=True),
        sa.Column("qr_code_id", sa.Integer(), nullable=True),
        sa.Column("idempotency_key", sa.String(length=128), nullable=False),
        sa.Column("remarks", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "amount > 0",
            name=op.f("ck_point_transfers_positive_transfer_amount"),
        ),
        sa.CheckConstraint(
            "sender_id != recipient_id",
            name=op.f("ck_point_transfers_distinct_transfer_sender_recipient"),
        ),
        sa.ForeignKeyConstraint(
            ["sender_id"],
            ["users.id"],
            name=op.f("fk_point_transfers_sender_id_users"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["recipient_id"],
            ["users.id"],
            name=op.f("fk_point_transfers_recipient_id_users"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["points_rule_id"],
            ["points_rules.id"],
            name=op.f("fk_point_transfers_points_rule_id_points_rules"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["qr_code_id"],
            ["qr_codes.id"],
            name=op.f("fk_point_transfers_qr_code_id_qr_codes"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_point_transfers")),
        sa.UniqueConstraint(
            "idempotency_key",
            name=op.f("uq_point_transfers_idempotency_key"),
        ),
    )
    op.create_index(
        "ix_point_transfers_sender_id", "point_transfers", ["sender_id"]
    )
    op.create_index(
        "ix_point_transfers_recipient_id", "point_transfers", ["recipient_id"]
    )
    op.create_index(
        "ix_point_transfers_points_rule_id",
        "point_transfers",
        ["points_rule_id"],
    )
    op.create_index(
        "ix_point_transfers_qr_code_id", "point_transfers", ["qr_code_id"]
    )
    op.create_index(
        "ix_point_transfers_created_at", "point_transfers", ["created_at"]
    )


def downgrade() -> None:
    context = op.get_context()
    if not getattr(context, "as_sql", False):
        bind = op.get_bind()
        if bind is not None and getattr(bind.dialect, "name", "") != "mock":
            insp = sa.inspect(bind)
            table_names = set(insp.get_table_names())
            if "point_transfers" in table_names:
                pt_count = bind.execute(
                    sa.text("SELECT COUNT(1) FROM point_transfers")
                ).scalar()
                if pt_count and pt_count > 0:
                    raise RuntimeError(
                        f"Cannot safely downgrade migration '{revision}': found {pt_count} point transfer(s) "
                        "in 'point_transfers'. Dropping this table would destroy points transfer ledger history. "
                        "To proceed with downgrade, manually archive or export point transfers first."
                    )

    op.drop_index("ix_point_transfers_created_at", table_name="point_transfers")
    op.drop_index("ix_point_transfers_qr_code_id", table_name="point_transfers")
    op.drop_index(
        "ix_point_transfers_points_rule_id", table_name="point_transfers"
    )
    op.drop_index(
        "ix_point_transfers_recipient_id", table_name="point_transfers"
    )
    op.drop_index("ix_point_transfers_sender_id", table_name="point_transfers")
    op.drop_table("point_transfers")
