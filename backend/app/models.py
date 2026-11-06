from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    func,
    text,
    true,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "role IN ('customer', 'partner', 'staff', 'admin')",
            name="supported_role",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    mobile: Mapped[str] = mapped_column(String(20), nullable=False, unique=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=true()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    customer_profile: Mapped[Optional[CustomerProfile]] = relationship(
        back_populates="user", passive_deletes="all"
    )
    partner_profile: Mapped[Optional[PartnerProfile]] = relationship(
        back_populates="user", passive_deletes="all"
    )
    staff_profile: Mapped[Optional[StaffProfile]] = relationship(
        back_populates="user", passive_deletes="all"
    )


class CustomerProfile(Base):
    __tablename__ = "customer_profiles"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    state: Mapped[Optional[str]] = mapped_column(String(100))
    city: Mapped[Optional[str]] = mapped_column(String(100))
    segment: Mapped[Optional[str]] = mapped_column(String(100))

    user: Mapped[User] = relationship(back_populates="customer_profile")


class Zone(Base):
    __tablename__ = "zones"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=true()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    partners: Mapped[list[PartnerProfile]] = relationship(back_populates="zone")


class PartnerProfile(Base):
    __tablename__ = "partner_profiles"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    business_name: Mapped[str] = mapped_column(String(200), nullable=False)
    business_address: Mapped[str] = mapped_column(Text, nullable=False)
    partner_code: Mapped[Optional[str]] = mapped_column(
        String(50), unique=True, nullable=True
    )
    zone_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("zones.id", ondelete="SET NULL"), nullable=True
    )

    user: Mapped[User] = relationship(back_populates="partner_profile")
    zone: Mapped[Optional[Zone]] = relationship(back_populates="partners")


class StaffProfile(Base):
    __tablename__ = "staff_profiles"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    staff_id: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)

    user: Mapped[User] = relationship(back_populates="staff_profile")


class OtpVerification(Base):
    __tablename__ = "otp_verifications"
    __table_args__ = (
        CheckConstraint("attempts >= 0", name="nonnegative_attempts"),
        Index("ix_otp_verifications_mobile", "mobile"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    mobile: Mapped[str] = mapped_column(String(20), nullable=False)
    otp_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    verified_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )


class ProductCategory(Base):
    __tablename__ = "product_categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(150), nullable=False, unique=True)
    description: Mapped[Optional[str]] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=true()
    )


class Product(Base):
    __tablename__ = "products"
    __table_args__ = (
        CheckConstraint(
            "vehicle_type IN ('2-Wheeler', '3-Wheeler', 'Both')",
            name="supported_vehicle_type",
        ),
        CheckConstraint("price >= 0", name="nonnegative_price"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("product_categories.id", ondelete="RESTRICT"), nullable=False
    )
    product_code: Mapped[str] = mapped_column(String(50), nullable=False)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text)
    package_quantity: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    vehicle_type: Mapped[str] = mapped_column(String(20), nullable=False)
    price: Mapped[Optional[Decimal]] = mapped_column(Numeric(12, 2), nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(2048))
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=true()
    )

    category: Mapped[ProductCategory] = relationship()


class CatalogueImportAudit(Base):
    __tablename__ = "catalogue_import_audit"
    __table_args__ = (
        Index(
            "ix_catalogue_import_audit_workbook_worksheet_row",
            "workbook_name",
            "worksheet_name",
            "excel_row_number",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    workbook_name: Mapped[str] = mapped_column(String(120), nullable=False)
    worksheet_name: Mapped[str] = mapped_column(String(120), nullable=False)
    excel_row_number: Mapped[int] = mapped_column(Integer, nullable=False)
    product_code: Mapped[str] = mapped_column(String(50), nullable=False)
    product_name: Mapped[str] = mapped_column(String(200), nullable=False)
    source_row_fingerprint: Mapped[str] = mapped_column(String(128), nullable=False, unique=True)
    imported_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Order(Base):
    __tablename__ = "orders"
    __table_args__ = (
        CheckConstraint(
            "status IN "
            "('pending_approval', 'approved_processing', 'dispatched', "
            "'delivered', 'rejected', 'cancelled')",
            name="supported_status",
        ),
        Index("ix_orders_partner_id", "partner_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    order_number: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    partner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(30), nullable=False, default="pending_approval",
        server_default="pending_approval",
    )
    notes: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    approved_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT")
    )
    approved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))

    partner: Mapped[User] = relationship(foreign_keys=[partner_id])
    approver: Mapped[Optional[User]] = relationship(foreign_keys=[approved_by])
    items: Mapped[list[OrderItem]] = relationship(
        back_populates="order", passive_deletes="all"
    )
    status_history: Mapped[list[OrderStatusHistory]] = relationship(
        back_populates="order", passive_deletes="all"
    )


class OrderItem(Base):
    __tablename__ = "order_items"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="positive_quantity"),
        CheckConstraint("unit_price >= 0", name="nonnegative_unit_price"),
        Index("ix_order_items_order_id", "order_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(
        ForeignKey("orders.id", ondelete="RESTRICT"), nullable=False
    )
    product_id: Mapped[int] = mapped_column(
        ForeignKey("products.id", ondelete="RESTRICT"), nullable=False
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)

    order: Mapped[Order] = relationship(back_populates="items")
    product: Mapped[Product] = relationship()


class OrderStatusHistory(Base):
    __tablename__ = "order_status_history"
    __table_args__ = (
        CheckConstraint(
            "new_status IN "
            "('pending_approval', 'approved_processing', 'dispatched', "
            "'delivered', 'rejected', 'cancelled')",
            name="supported_new_status",
        ),
        CheckConstraint(
            "old_status IS NULL OR old_status IN "
            "('pending_approval', 'approved_processing', 'dispatched', "
            "'delivered', 'rejected', 'cancelled')",
            name="supported_old_status",
        ),
        Index("ix_order_status_history_order_id", "order_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(
        ForeignKey("orders.id", ondelete="RESTRICT"), nullable=False
    )
    old_status: Mapped[Optional[str]] = mapped_column(String(30))
    new_status: Mapped[str] = mapped_column(String(30), nullable=False)
    changed_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT")
    )
    changed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    remarks: Mapped[Optional[str]] = mapped_column(Text)

    order: Mapped[Order] = relationship(back_populates="status_history")
    actor: Mapped[Optional[User]] = relationship()


class StockRequest(Base):
    __tablename__ = "stock_requests"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending_approval', 'approved', 'rejected')",
            name="supported_status",
        ),
        Index("ix_stock_requests_partner_id", "partner_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    request_number: Mapped[str] = mapped_column(
        String(50), nullable=False, unique=True
    )
    partner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(30), nullable=False, default="pending_approval",
        server_default="pending_approval",
    )
    notes: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    reviewed_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT")
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))

    partner: Mapped[User] = relationship(foreign_keys=[partner_id])
    reviewer: Mapped[Optional[User]] = relationship(foreign_keys=[reviewed_by])
    items: Mapped[list[StockRequestItem]] = relationship(
        back_populates="stock_request", passive_deletes="all"
    )
    status_history: Mapped[list[StockRequestStatusHistory]] = relationship(
        back_populates="stock_request", passive_deletes="all"
    )


class StockRequestItem(Base):
    __tablename__ = "stock_request_items"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="positive_quantity"),
        Index("ix_stock_request_items_request_id", "stock_request_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    stock_request_id: Mapped[int] = mapped_column(
        ForeignKey("stock_requests.id", ondelete="RESTRICT"), nullable=False
    )
    product_id: Mapped[int] = mapped_column(
        ForeignKey("products.id", ondelete="RESTRICT"), nullable=False
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)

    stock_request: Mapped[StockRequest] = relationship(back_populates="items")
    product: Mapped[Product] = relationship()


class StockRequestStatusHistory(Base):
    __tablename__ = "stock_request_status_history"
    __table_args__ = (
        CheckConstraint(
            "new_status IN ('pending_approval', 'approved', 'rejected')",
            name="supported_new_status",
        ),
        CheckConstraint(
            "old_status IS NULL OR old_status IN "
            "('pending_approval', 'approved', 'rejected')",
            name="supported_old_status",
        ),
        Index("ix_stock_request_status_history_request_id", "stock_request_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    stock_request_id: Mapped[int] = mapped_column(
        ForeignKey("stock_requests.id", ondelete="RESTRICT"), nullable=False
    )
    old_status: Mapped[Optional[str]] = mapped_column(String(30))
    new_status: Mapped[str] = mapped_column(String(30), nullable=False)
    changed_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT")
    )
    changed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    remarks: Mapped[Optional[str]] = mapped_column(Text)

    stock_request: Mapped[StockRequest] = relationship(back_populates="status_history")
    actor: Mapped[Optional[User]] = relationship()


class StaffPartnerAssignment(Base):
    __tablename__ = "staff_partner_assignments"
    __table_args__ = (
        Index(
            "uq_staff_partner_assignments_active_pair",
            "staff_id",
            "partner_id",
            unique=True,
            postgresql_where=text("is_active IS TRUE"),
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    staff_id: Mapped[int] = mapped_column(
        ForeignKey("staff_profiles.user_id", ondelete="RESTRICT"), nullable=False
    )
    partner_id: Mapped[int] = mapped_column(
        ForeignKey("partner_profiles.user_id", ondelete="RESTRICT"), nullable=False
    )
    assigned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=true()
    )

    staff: Mapped[StaffProfile] = relationship()
    partner: Mapped[PartnerProfile] = relationship()


class StaffPaymentRecord(Base):
    __tablename__ = "staff_payment_records"
    __table_args__ = (
        CheckConstraint("amount > 0", name="positive_amount"),
        CheckConstraint(
            "status IN ('recorded', 'voided')", name="supported_status"
        ),
        Index("ix_staff_payment_records_partner_id", "partner_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    staff_id: Mapped[int] = mapped_column(
        ForeignKey("staff_profiles.user_id", ondelete="RESTRICT"), nullable=False
    )
    partner_id: Mapped[int] = mapped_column(
        ForeignKey("partner_profiles.user_id", ondelete="RESTRICT"), nullable=False
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    payment_method: Mapped[str] = mapped_column(String(50), nullable=False)
    reference_number: Mapped[Optional[str]] = mapped_column(String(100))
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="recorded", server_default="recorded"
    )
    recorded_by: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    recorded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    notes: Mapped[Optional[str]] = mapped_column(Text)

    staff: Mapped[StaffProfile] = relationship()
    partner: Mapped[PartnerProfile] = relationship()
    actor: Mapped[User] = relationship()
    status_history: Mapped[list[PaymentStatusHistory]] = relationship(
        back_populates="payment_record", passive_deletes="all"
    )


class PaymentStatusHistory(Base):
    __tablename__ = "payment_status_history"
    __table_args__ = (
        CheckConstraint(
            "new_status IN ('recorded', 'voided')", name="supported_new_status"
        ),
        CheckConstraint(
            "old_status IS NULL OR old_status IN ('recorded', 'voided')",
            name="supported_old_status",
        ),
        Index("ix_payment_status_history_payment_record_id", "payment_record_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    payment_record_id: Mapped[int] = mapped_column(
        ForeignKey("staff_payment_records.id", ondelete="RESTRICT"), nullable=False
    )
    old_status: Mapped[Optional[str]] = mapped_column(String(20))
    new_status: Mapped[str] = mapped_column(String(20), nullable=False)
    changed_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT")
    )
    changed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    payment_record: Mapped[StaffPaymentRecord] = relationship(
        back_populates="status_history"
    )
    actor: Mapped[Optional[User]] = relationship()


class PointsRule(Base):
    __tablename__ = "points_rules"
    __table_args__ = (
        CheckConstraint(
            "category IN ('product_qr_scan', 'invoice_qr_scan', 'redemption', "
            "'customer_to_partner_transfer', 'partner_to_staff_transfer')",
            name="supported_rule_category",
        ),
        CheckConstraint(
            "points_awarded IS NULL OR points_awarded >= 0",
            name="nonnegative_points_awarded",
        ),
        CheckConstraint(
            "points_required IS NULL OR points_required >= 0",
            name="nonnegative_points_required",
        ),
        CheckConstraint(
            "min_transaction_value IS NULL OR min_transaction_value >= 0",
            name="nonnegative_min_transaction_value",
        ),
        CheckConstraint(
            "max_transaction_value IS NULL OR max_transaction_value >= 0",
            name="nonnegative_max_transaction_value",
        ),
        Index("ix_points_rules_category", "category"),
        Index("ix_points_rules_is_active", "is_active"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    rule_name: Mapped[str] = mapped_column(String(120), nullable=False)
    rule_description: Mapped[Optional[str]] = mapped_column(Text)
    category: Mapped[str] = mapped_column(String(50), nullable=False)
    points_awarded: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    points_required: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    min_transaction_value: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(12, 2), nullable=True
    )
    max_transaction_value: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(12, 2), nullable=True
    )
    effective_from: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    effective_to: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=true()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
    created_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    updated_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    creator: Mapped[Optional[User]] = relationship(foreign_keys=[created_by])
    updater: Mapped[Optional[User]] = relationship(foreign_keys=[updated_by])


class QrBatch(Base):
    __tablename__ = "qr_batches"
    __table_args__ = (
        CheckConstraint(
            "qr_type IN ('product', 'invoice', 'staff', 'partner')",
            name="supported_qr_type",
        ),
        CheckConstraint(
            "status IN ('active', 'completed', 'cancelled')",
            name="valid_qr_batch_status",
        ),
        CheckConstraint(
            "quantity > 0 AND quantity <= 1000",
            name="valid_qr_batch_quantity",
        ),
        Index("ix_qr_batches_batch_number", "batch_number", unique=True),
        Index("ix_qr_batches_qr_type", "qr_type"),
        Index("ix_qr_batches_status", "status"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    batch_number: Mapped[str] = mapped_column(String(60), nullable=False, unique=True)
    qr_type: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text)
    points_rule_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("points_rules.id", ondelete="SET NULL"), nullable=True
    )
    product_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("products.id", ondelete="SET NULL"), nullable=True
    )
    target_user_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="completed", server_default="completed"
    )
    metadata_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    points_rule: Mapped[Optional[PointsRule]] = relationship()
    product: Mapped[Optional[Product]] = relationship()
    target_user: Mapped[Optional[User]] = relationship(foreign_keys=[target_user_id])
    creator: Mapped[Optional[User]] = relationship(foreign_keys=[created_by])
    codes: Mapped[list[QrCode]] = relationship(
        back_populates="batch", cascade="all, delete-orphan"
    )


class QrCode(Base):
    __tablename__ = "qr_codes"
    __table_args__ = (
        CheckConstraint(
            "qr_type IN ('product', 'invoice', 'staff', 'partner')",
            name="supported_code_qr_type",
        ),
        CheckConstraint(
            "status IN ('active', 'redeemed', 'voided', 'expired')",
            name="valid_qr_code_status",
        ),
        Index("ix_qr_codes_token", "token", unique=True),
        Index("ix_qr_codes_batch_id", "batch_id"),
        Index("ix_qr_codes_qr_type", "qr_type"),
        Index("ix_qr_codes_status", "status"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    batch_id: Mapped[int] = mapped_column(
        ForeignKey("qr_batches.id", ondelete="CASCADE"), nullable=False
    )
    qr_type: Mapped[str] = mapped_column(String(50), nullable=False)
    token: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    code_data: Mapped[str] = mapped_column(Text, nullable=False)
    points_awarded: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    product_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("products.id", ondelete="SET NULL"), nullable=True
    )
    target_user_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="active", server_default="active"
    )
    redeemed_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    redeemed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    batch: Mapped[QrBatch] = relationship(back_populates="codes")
    product: Mapped[Optional[Product]] = relationship()
    target_user: Mapped[Optional[User]] = relationship(foreign_keys=[target_user_id])
    redeemer: Mapped[Optional[User]] = relationship(foreign_keys=[redeemed_by])
