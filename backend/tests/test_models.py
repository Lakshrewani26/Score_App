import ast
from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import Numeric, UniqueConstraint
from sqlalchemy.orm import configure_mappers

from app.db.base import Base
from app.models import OrderItem, Product, StaffPartnerAssignment


EXPECTED_TABLES = {
    "users",
    "customer_profiles",
    "partner_profiles",
    "staff_profiles",
    "otp_verifications",
    "product_categories",
    "products",
    "catalogue_import_audit",
    "orders",
    "order_items",
    "order_status_history",
    "stock_requests",
    "stock_request_items",
    "stock_request_status_history",
    "staff_partner_assignments",
    "staff_payment_records",
    "payment_status_history",
    "points_rules",
    "qr_batches",
    "qr_codes",
}

INITIAL_EXPECTED_TABLES = EXPECTED_TABLES - {
    "catalogue_import_audit",
    "points_rules",
    "qr_batches",
    "qr_codes",
}


def test_all_models_are_registered_in_shared_metadata() -> None:
    assert set(Base.metadata.tables) == EXPECTED_TABLES
    configure_mappers()


def test_required_unique_constraints_and_foreign_keys_exist() -> None:
    users = Base.metadata.tables["users"]
    orders = Base.metadata.tables["orders"]
    assignments = Base.metadata.tables["staff_partner_assignments"]

    assert any(
        isinstance(constraint, UniqueConstraint)
        and {column.name for column in constraint.columns} == {"mobile"}
        for constraint in users.constraints
    )
    assert any(
        foreign_key.target_fullname == "users.id"
        for foreign_key in orders.c.partner_id.foreign_keys
    )
    assert {
        foreign_key.target_fullname
        for foreign_key in Base.metadata.tables["order_items"].c.product_id.foreign_keys
    } == {"products.id"}
    assert {
        foreign_key.target_fullname
        for foreign_key in Base.metadata.tables["order_items"].c.order_id.foreign_keys
    } == {"orders.id"}
    assert {
        foreign_key.target_fullname
        for foreign_key in Base.metadata.tables["customer_profiles"].c.user_id.foreign_keys
    } == {"users.id"}
    assert any(
        index.unique
        and index.name == "uq_staff_partner_assignments_active_pair"
        and "is_active" in str(index.dialect_options["postgresql"]["where"])
        for index in assignments.indexes
    )


def test_money_columns_use_fixed_precision_numeric_types() -> None:
    assert isinstance(Product.__table__.c.price.type, Numeric)
    assert (Product.__table__.c.price.type.precision, Product.__table__.c.price.type.scale) == (
        12,
        2,
    )
    assert isinstance(OrderItem.__table__.c.unit_price.type, Numeric)
    assert (
        OrderItem.__table__.c.unit_price.type.precision,
        OrderItem.__table__.c.unit_price.type.scale,
    ) == (12, 2)


def test_supported_vehicle_types_and_price_checks_are_declared() -> None:
    constraints = {
        constraint.name: str(constraint.sqltext)
        for constraint in Product.__table__.constraints
        if hasattr(constraint, "sqltext")
    }

    assert "ck_products_supported_vehicle_type" in constraints
    assert "'2-Wheeler'" in constraints["ck_products_supported_vehicle_type"]
    assert "'3-Wheeler'" in constraints["ck_products_supported_vehicle_type"]
    assert "'Both'" in constraints["ck_products_supported_vehicle_type"]
    assert "ck_products_nonnegative_price" in constraints


def test_single_initial_alembic_revision_is_available() -> None:
    backend_dir = Path(__file__).resolve().parents[1]
    config = Config(str(backend_dir / "alembic.ini"))
    config.set_main_option("script_location", str(backend_dir / "migrations"))
    scripts = ScriptDirectory.from_config(config)

    assert len(scripts.get_heads()) == 1
    assert len(list(scripts.walk_revisions())) == 4
    revision = scripts.get_revision("56ecec28acb3")
    assert revision is not None
    assert revision.down_revision is None
    migration_tree = ast.parse(Path(revision.path).read_text(encoding="utf-8"))
    created_tables = {
        node.args[0].value
        for node in ast.walk(migration_tree)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and isinstance(node.func.value, ast.Name)
        and node.func.value.id == "op"
        and node.func.attr == "create_table"
        and node.args
        and isinstance(node.args[0], ast.Constant)
    }
    assert created_tables == INITIAL_EXPECTED_TABLES
