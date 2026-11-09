from __future__ import annotations

import importlib.util
from pathlib import Path
import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool
from alembic.migration import MigrationContext
from alembic.operations import Operations

from app.core.security import hash_password
from app.db.base import Base
from app.models import (
    PartnerProfile,
    PointTransfer,
    PointsRule,
    QrBatch,
    QrCode,
    StaffProfile,
    User,
)


@pytest.fixture
def transfer_engine():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    with engine.begin() as conn:
        conn.exec_driver_sql("PRAGMA foreign_keys = ON")
    Base.metadata.create_all(bind=engine)
    yield engine
    engine.dispose()


@pytest.fixture
def db(transfer_engine):
    with Session(transfer_engine, expire_on_commit=False) as session:
        yield session


@pytest.fixture
def seed_users(db: Session):
    partner_user = User(
        name="Partner Store One",
        mobile="9800000001",
        password_hash=hash_password("partner123"),
        role="partner",
        is_active=True,
    )
    partner_user_2 = User(
        name="Partner Store Two",
        mobile="9800000002",
        password_hash=hash_password("partner123"),
        role="partner",
        is_active=True,
    )
    staff_user = User(
        name="Staff Member A",
        mobile="9800000003",
        password_hash=hash_password("staff123"),
        role="staff",
        is_active=True,
    )
    admin_user = User(
        name="Admin User",
        mobile="9800000004",
        password_hash=hash_password("admin123"),
        role="admin",
        is_active=True,
    )
    db.add_all([partner_user, partner_user_2, staff_user, admin_user])
    db.flush()

    partner_profile = PartnerProfile(
        user_id=partner_user.id,
        business_name="Partner Store One",
        business_address="123 Business St",
        partner_code="PAR-001",
    )
    partner_profile_2 = PartnerProfile(
        user_id=partner_user_2.id,
        business_name="Partner Store Two",
        business_address="456 Market St",
        partner_code="PAR-002",
    )
    staff_profile = StaffProfile(
        user_id=staff_user.id,
        staff_id="STF-001",
    )
    transfer_rule = PointsRule(
        rule_name="Partner to Staff Transfer Policy",
        category="partner_to_staff_transfer",
        points_awarded=100,
        is_active=True,
        is_current=True,
        version=1,
    )
    db.add_all([partner_profile, partner_profile_2, staff_profile, transfer_rule])
    db.flush()

    qr_batch = QrBatch(
        batch_number="BATCH-STF-001",
        qr_type="staff",
        quantity=1,
        target_user_id=staff_user.id,
    )
    db.add(qr_batch)
    db.flush()

    qr_code = QrCode(
        batch_id=qr_batch.id,
        qr_type="staff",
        token="STAFF_QR_TOKEN_ABC123",
        code_data="https://score.app/qr/staff?token=STAFF_QR_TOKEN_ABC123",
        target_user_id=staff_user.id,
        status="active",
    )
    db.add(qr_code)
    db.commit()

    return {
        "partner": partner_user,
        "partner_2": partner_user_2,
        "staff": staff_user,
        "admin": admin_user,
        "rule": transfer_rule,
        "qr_code": qr_code,
    }


def test_point_transfer_successful_creation(db: Session, seed_users):
    partner = seed_users["partner"]
    staff = seed_users["staff"]
    rule = seed_users["rule"]
    qr = seed_users["qr_code"]

    transfer = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=250,
        points_rule_id=rule.id,
        qr_code_id=qr.id,
        idempotency_key="transfer-req-key-001",
        remarks="Performance incentive transfer",
    )
    db.add(transfer)
    db.commit()

    saved = db.scalar(
        select(PointTransfer).where(PointTransfer.idempotency_key == "transfer-req-key-001")
    )
    assert saved is not None
    assert saved.id is not None
    assert saved.sender_id == partner.id
    assert saved.recipient_id == staff.id
    assert saved.amount == 250
    assert saved.points_rule_id == rule.id
    assert saved.qr_code_id == qr.id
    assert saved.remarks == "Performance incentive transfer"
    assert saved.created_at is not None

    # Verify ORM relationships
    assert saved.sender.name == "Partner Store One"
    assert saved.recipient.name == "Staff Member A"
    assert saved.points_rule.rule_name == "Partner to Staff Transfer Policy"
    assert saved.qr_code.token == "STAFF_QR_TOKEN_ABC123"


def test_staff_can_receive_multiple_transfers(db: Session, seed_users):
    partner_1 = seed_users["partner"]
    partner_2 = seed_users["partner_2"]
    staff = seed_users["staff"]
    rule = seed_users["rule"]
    qr = seed_users["qr_code"]

    # Transfer 1 from Partner 1 to Staff
    t1 = PointTransfer(
        sender_id=partner_1.id,
        recipient_id=staff.id,
        amount=100,
        points_rule_id=rule.id,
        qr_code_id=qr.id,
        idempotency_key="tx-mult-001",
    )
    # Transfer 2 from Partner 1 to Staff again
    t2 = PointTransfer(
        sender_id=partner_1.id,
        recipient_id=staff.id,
        amount=150,
        points_rule_id=rule.id,
        qr_code_id=qr.id,
        idempotency_key="tx-mult-002",
    )
    # Transfer 3 from Partner 2 to Staff
    t3 = PointTransfer(
        sender_id=partner_2.id,
        recipient_id=staff.id,
        amount=200,
        points_rule_id=rule.id,
        qr_code_id=qr.id,
        idempotency_key="tx-mult-003",
    )
    db.add_all([t1, t2, t3])
    db.commit()

    received = db.scalars(
        select(PointTransfer).where(PointTransfer.recipient_id == staff.id)
    ).all()
    assert len(received) == 3
    assert {t.amount for t in received} == {100, 150, 200}


def test_point_transfer_supports_optional_rule_and_qr_code(db: Session, seed_users):
    partner = seed_users["partner"]
    staff = seed_users["staff"]

    # Direct transfer with no QR code and no rule attached
    transfer = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=50,
        points_rule_id=None,
        qr_code_id=None,
        remarks=None,
        idempotency_key="tx-direct-no-qr-001",
    )
    db.add(transfer)
    db.commit()

    saved = db.scalar(
        select(PointTransfer).where(PointTransfer.idempotency_key == "tx-direct-no-qr-001")
    )
    assert saved is not None
    assert saved.points_rule_id is None
    assert saved.qr_code_id is None
    assert saved.remarks is None
    assert saved.points_rule is None
    assert saved.qr_code is None


def test_point_transfer_rejects_non_positive_amount(db: Session, seed_users):
    partner = seed_users["partner"]
    staff = seed_users["staff"]

    # Zero amount
    t_zero = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=0,
        idempotency_key="tx-zero-amount",
    )
    db.add(t_zero)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()

    # Negative amount
    t_neg = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=-50,
        idempotency_key="tx-neg-amount",
    )
    db.add(t_neg)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_point_transfer_rejects_same_sender_and_recipient(db: Session, seed_users):
    partner = seed_users["partner"]

    # Sender and recipient are the same user
    t_self = PointTransfer(
        sender_id=partner.id,
        recipient_id=partner.id,
        amount=100,
        idempotency_key="tx-self-transfer",
    )
    db.add(t_self)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_point_transfer_enforces_idempotency_at_db_level(db: Session, seed_users):
    partner = seed_users["partner"]
    staff = seed_users["staff"]

    t1 = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=100,
        idempotency_key="duplicate-idempotency-key-xyz",
    )
    db.add(t1)
    db.commit()

    # Duplicate idempotency_key must raise IntegrityError
    t2 = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=100,
        idempotency_key="duplicate-idempotency-key-xyz",
    )
    db.add(t2)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_point_transfer_same_qr_code_multiple_times(db: Session, seed_users):
    partner = seed_users["partner"]
    staff = seed_users["staff"]
    qr = seed_users["qr_code"]

    # Same qr_code_id can be referenced across multiple transfers
    t1 = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=100,
        qr_code_id=qr.id,
        idempotency_key="tx-qr-reuse-001",
    )
    t2 = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=150,
        qr_code_id=qr.id,
        idempotency_key="tx-qr-reuse-002",
    )
    db.add_all([t1, t2])
    db.commit()

    transfers = db.scalars(
        select(PointTransfer).where(PointTransfer.qr_code_id == qr.id)
    ).all()
    assert len(transfers) >= 2


def test_point_transfer_rejects_null_idempotency_key(db: Session, seed_users):
    partner = seed_users["partner"]
    staff = seed_users["staff"]

    t = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=100,
        idempotency_key=None,
    )
    db.add(t)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_point_transfer_foreign_key_sender_must_exist(db: Session, seed_users):
    staff = seed_users["staff"]

    t = PointTransfer(
        sender_id=999999,
        recipient_id=staff.id,
        amount=100,
        idempotency_key="tx-invalid-sender",
    )
    db.add(t)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_point_transfer_foreign_key_recipient_must_exist(db: Session, seed_users):
    partner = seed_users["partner"]

    t = PointTransfer(
        sender_id=partner.id,
        recipient_id=999999,
        amount=100,
        idempotency_key="tx-invalid-recipient",
    )
    db.add(t)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()



def test_point_transfer_migration_downgrade_data_safety_check():
    backend_dir = Path(__file__).resolve().parents[1]
    migration_path = (
        backend_dir
        / "migrations"
        / "versions"
        / "b3c4d5e6f7a8_create_point_transfers_table.py"
    )
    spec = importlib.util.spec_from_file_location(
        "point_transfers_migration", migration_path
    )
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    engine = create_engine("sqlite://")
    with engine.begin() as connection:
        connection.exec_driver_sql(
            "CREATE TABLE users (id INTEGER PRIMARY KEY, name VARCHAR(150))"
        )
        connection.exec_driver_sql(
            "CREATE TABLE points_rules (id INTEGER PRIMARY KEY, rule_name VARCHAR(120), category VARCHAR(50))"
        )
        connection.exec_driver_sql(
            "CREATE TABLE qr_codes (id INTEGER PRIMARY KEY, token VARCHAR(64))"
        )
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

        # Insert a transfer record
        connection.exec_driver_sql(
            "INSERT INTO point_transfers (sender_id, recipient_id, amount, idempotency_key) "
            "VALUES (1, 2, 100, 'audit-protection-key-1')"
        )

        # Downgrading with existing records must raise RuntimeError
        with pytest.raises(RuntimeError) as exc_info:
            with Operations.context(MigrationContext.configure(connection)):
                migration.downgrade()

        assert "found 1 point transfer(s)" in str(exc_info.value)
        assert "Dropping this table would destroy points transfer ledger history" in str(exc_info.value)

    engine.dispose()
