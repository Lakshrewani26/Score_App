"""Expand payment status lifecycle and add remarks to payment status history.

Revision ID: c4d5e6f7a8b9
Revises: b3c4d5e6f7a8
Create Date: 2026-11-13 20:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c4d5e6f7a8b9"
down_revision: Union[str, None] = "b3c4d5e6f7a8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    is_sqlite = bind is not None and getattr(bind.dialect, "name", "") == "sqlite"

    payment_checks = set()
    history_checks = set()
    if is_sqlite and bind is not None:
        insp = sa.inspect(bind)
        payment_checks = {c["name"] for c in insp.get_check_constraints("staff_payment_records")}
        history_checks = {c["name"] for c in insp.get_check_constraints("payment_status_history")}

    with op.batch_alter_table("staff_payment_records") as batch_op:
        if not is_sqlite or ("ck_staff_payment_records_supported_status" in payment_checks):
            batch_op.drop_constraint(op.f("ck_staff_payment_records_supported_status"), type_="check")
        batch_op.create_check_constraint(
            op.f("ck_staff_payment_records_supported_status"),
            "status IN ('recorded', 'approved', 'rejected', 'voided')",
        )

    with op.batch_alter_table("payment_status_history") as batch_op:
        batch_op.add_column(sa.Column("remarks", sa.Text(), nullable=True))
        if not is_sqlite or ("ck_payment_status_history_supported_new_status" in history_checks):
            batch_op.drop_constraint(op.f("ck_payment_status_history_supported_new_status"), type_="check")
        if not is_sqlite or ("ck_payment_status_history_supported_old_status" in history_checks):
            batch_op.drop_constraint(op.f("ck_payment_status_history_supported_old_status"), type_="check")
        batch_op.create_check_constraint(
            op.f("ck_payment_status_history_supported_new_status"),
            "new_status IN ('recorded', 'approved', 'rejected', 'voided')",
        )
        batch_op.create_check_constraint(
            op.f("ck_payment_status_history_supported_old_status"),
            "old_status IS NULL OR old_status IN ('recorded', 'approved', 'rejected', 'voided')",
        )


def downgrade() -> None:
    bind = op.get_bind()
    is_sqlite = bind is not None and getattr(bind.dialect, "name", "") == "sqlite"

    payment_checks = set()
    history_checks = set()
    if is_sqlite and bind is not None:
        insp = sa.inspect(bind)
        payment_checks = {c["name"] for c in insp.get_check_constraints("staff_payment_records")}
        history_checks = {c["name"] for c in insp.get_check_constraints("payment_status_history")}

    with op.batch_alter_table("payment_status_history") as batch_op:
        batch_op.drop_column("remarks")
        if not is_sqlite or ("ck_payment_status_history_supported_new_status" in history_checks):
            batch_op.drop_constraint(op.f("ck_payment_status_history_supported_new_status"), type_="check")
        if not is_sqlite or ("ck_payment_status_history_supported_old_status" in history_checks):
            batch_op.drop_constraint(op.f("ck_payment_status_history_supported_old_status"), type_="check")
        batch_op.create_check_constraint(
            op.f("ck_payment_status_history_supported_new_status"),
            "new_status IN ('recorded', 'voided')",
        )
        batch_op.create_check_constraint(
            op.f("ck_payment_status_history_supported_old_status"),
            "old_status IS NULL OR old_status IN ('recorded', 'voided')",
        )

    with op.batch_alter_table("staff_payment_records") as batch_op:
        if not is_sqlite or ("ck_staff_payment_records_supported_status" in payment_checks):
            batch_op.drop_constraint(op.f("ck_staff_payment_records_supported_status"), type_="check")
        batch_op.create_check_constraint(
            op.f("ck_staff_payment_records_supported_status"),
            "status IN ('recorded', 'voided')",
        )
