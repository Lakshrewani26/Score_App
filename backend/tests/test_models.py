import ast
import importlib.util
from pathlib import Path

from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import Numeric, String, UniqueConstraint, create_engine, inspect
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
    "zones",
    "point_transactions",
}

INITIAL_EXPECTED_TABLES = EXPECTED_TABLES - {
    "catalogue_import_audit",
    "points_rules",
    "qr_batches",
    "qr_codes",
    "zones",
    "point_transactions",
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


def test_product_package_quantity_is_nullable_string() -> None:
    package_quantity = Product.__table__.c.package_quantity

    assert isinstance(package_quantity.type, String)
    assert package_quantity.type.length == 100
    assert package_quantity.nullable


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
    assert len(list(scripts.walk_revisions())) == 7
    latest_revision = scripts.get_revision("a1b2c3d4e5f6")
    assert latest_revision is not None
    assert latest_revision.down_revision == "f3b2c1d4e5a6"
    assert scripts.get_heads() == ["a1b2c3d4e5f6"]
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


def test_package_quantity_migration_upgrade_and_downgrade() -> None:
    backend_dir = Path(__file__).resolve().parents[1]
    migration_path = (
        backend_dir
        / "migrations"
        / "versions"
        / "c9a4f0e2b713_add_package_quantity_to_products.py"
    )
    spec = importlib.util.spec_from_file_location(
        "package_quantity_migration", migration_path
    )
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    engine = create_engine("sqlite://")
    with engine.begin() as connection:
        connection.exec_driver_sql("CREATE TABLE products (id INTEGER PRIMARY KEY)")
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

        column = next(
            column
            for column in inspect(connection).get_columns("products")
            if column["name"] == "package_quantity"
        )
        assert isinstance(column["type"], String)
        assert column["type"].length == 100
        assert column["nullable"]

        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()

        assert "package_quantity" not in {
            column["name"] for column in inspect(connection).get_columns("products")
        }
    engine.dispose()


def test_zones_migration_upgrade_and_downgrade() -> None:
    backend_dir = Path(__file__).resolve().parents[1]
    migration_path = (
        backend_dir
        / "migrations"
        / "versions"
        / "f3b2c1d4e5a6_create_zones_and_partner_zone_fk.py"
    )
    spec = importlib.util.spec_from_file_location(
        "zones_migration", migration_path
    )
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    engine = create_engine("sqlite://")
    with engine.begin() as connection:
        connection.exec_driver_sql(
            "CREATE TABLE partner_profiles (id INTEGER PRIMARY KEY, business_name VARCHAR(200))"
        )
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

        tables = set(inspect(connection).get_table_names())
        assert "zones" in tables

        column = next(
            column
            for column in inspect(connection).get_columns("partner_profiles")
            if column["name"] == "zone_id"
        )
        assert column["nullable"] is True

        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()

        tables_after = set(inspect(connection).get_table_names())
        assert "zones" not in tables_after
        assert "zone_id" not in {
            column["name"]
            for column in inspect(connection).get_columns("partner_profiles")
        }
    engine.dispose()


def test_loyalty_and_discounts_migration_upgrade_and_downgrade() -> None:
    backend_dir = Path(__file__).resolve().parents[1]
    migration_path = (
        backend_dir
        / "migrations"
        / "versions"
        / "a1b2c3d4e5f6_features_g_and_h_loyalty_and_discounts.py"
    )
    spec = importlib.util.spec_from_file_location(
        "loyalty_and_discounts_migration", migration_path
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
            "CREATE TABLE qr_codes (id INTEGER PRIMARY KEY, token VARCHAR(64))"
        )
        connection.exec_driver_sql(
            "CREATE TABLE points_rules (id INTEGER PRIMARY KEY, rule_name VARCHAR(120), category VARCHAR(50))"
        )
        connection.exec_driver_sql(
            "CREATE TABLE partner_profiles (user_id INTEGER PRIMARY KEY, business_name VARCHAR(200))"
        )
        connection.exec_driver_sql(
            "CREATE TABLE orders (id INTEGER PRIMARY KEY, order_number VARCHAR(50))"
        )
        connection.exec_driver_sql(
            "CREATE TABLE order_items (id INTEGER PRIMARY KEY, quantity INTEGER, unit_price NUMERIC)"
        )
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

        tables = set(inspect(connection).get_table_names())
        assert "point_transactions" in tables

        pr_cols = {c["name"] for c in inspect(connection).get_columns("points_rules")}
        assert "conversion_rate" in pr_cols
        assert "point_value" in pr_cols
        assert "version" in pr_cols
        assert "parent_rule_id" in pr_cols
        assert "is_current" in pr_cols

        partner_cols = {c["name"] for c in inspect(connection).get_columns("partner_profiles")}
        assert "discount_percentage" in partner_cols

        order_cols = {c["name"] for c in inspect(connection).get_columns("orders")}
        assert "subtotal_before_discount" in order_cols
        assert "discount_percentage" in order_cols
        assert "total_discount" in order_cols
        assert "final_total" in order_cols

        order_item_cols = {c["name"] for c in inspect(connection).get_columns("order_items")}
        assert "original_price" in order_item_cols
        assert "discount_percentage" in order_item_cols
        assert "discount_amount" in order_item_cols
        assert "discounted_price" in order_item_cols

        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()

        tables_after = set(inspect(connection).get_table_names())
        assert "point_transactions" not in tables_after
        pr_cols_after = {c["name"] for c in inspect(connection).get_columns("points_rules")}
        assert "conversion_rate" not in pr_cols_after
        assert "point_value" not in pr_cols_after
        assert "version" not in pr_cols_after
        assert "parent_rule_id" not in pr_cols_after
        assert "is_current" not in pr_cols_after

    engine.dispose()


