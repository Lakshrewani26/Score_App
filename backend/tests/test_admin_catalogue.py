from __future__ import annotations

from collections.abc import Generator
from decimal import Decimal
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.config import settings
from app.core.security import create_access_token, hash_password
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models import (
    CustomerProfile,
    PartnerProfile,
    Product,
    ProductCategory,
    StaffProfile,
    User,
)

TEST_SECRET_KEY = "test-secret-key-score-app-admin-panel-minimum-32-chars-long"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def configure_test_jwt_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "jwt_secret_key", TEST_SECRET_KEY)
    monkeypatch.setattr(settings, "jwt_algorithm", "HS256")
    monkeypatch.setattr(settings, "jwt_access_token_expire_minutes", 60)


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(
        bind=engine,
        tables=[
            User.__table__,
            CustomerProfile.__table__,
            PartnerProfile.__table__,
            StaffProfile.__table__,
            ProductCategory.__table__,
            Product.__table__,
        ],
    )

    def override_get_db() -> Generator[Session, None, None]:
        with Session(engine, expire_on_commit=False) as db:
            yield db

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)
    engine.dispose()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _create_user(
    db: Session,
    *,
    id: int | None = None,
    name: str = "Admin User",
    mobile: str = "9876543210",
    role: str = "admin",
    is_active: bool = True,
) -> User:
    user = User(
        name=name,
        mobile=mobile,
        password_hash=hash_password("SecurePassword123!"),
        role=role,
        is_active=is_active,
    )
    if id is not None:
        user.id = id
    db.add(user)
    db.commit()
    db.refresh(user)
    _ = (user.id, user.name, user.mobile, user.role, user.is_active)
    return user


def _auth_header(user: User) -> dict[str, str]:
    token = create_access_token(
        subject=str(user.id),
        role=user.role,
        mobile=user.mobile,
    )
    return {"Authorization": f"Bearer {token}"}


def _create_category(
    db: Session,
    *,
    name: str = "Brakes",
    description: str | None = "Brake components",
    is_active: bool = True,
) -> ProductCategory:
    cat = ProductCategory(
        name=name,
        description=description,
        is_active=is_active,
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)
    _ = (cat.id, cat.name, cat.description, cat.is_active)
    return cat


def _create_product(
    db: Session,
    *,
    category: ProductCategory,
    product_code: str = "BRK-01",
    name: str = "Front Brake Shoe",
    vehicle_type: str = "2-Wheeler",
    price: Decimal | None = Decimal("150.00"),
    description: str | None = "High friction shoe",
    image_url: str | None = None,
    is_active: bool = True,
) -> Product:
    prod = Product(
        category_id=category.id,
        product_code=product_code,
        name=name,
        vehicle_type=vehicle_type,
        price=price,
        description=description,
        image_url=image_url,
        is_active=is_active,
    )
    db.add(prod)
    db.commit()
    db.refresh(prod)
    _ = (
        prod.id,
        prod.product_code,
        prod.name,
        prod.category_id,
        prod.vehicle_type,
        prod.price,
        prod.description,
        prod.image_url,
        prod.is_active,
    )
    return prod


def _assert_no_sensitive_fields(data: Any) -> None:
    forbidden_keys = {"password", "password_hash", "hash", "secret"}
    if isinstance(data, dict):
        for k, v in data.items():
            assert k.lower() not in forbidden_keys, f"Sensitive key '{k}' leaked"
            _assert_no_sensitive_fields(v)
    elif isinstance(data, list):
        for item in data:
            _assert_no_sensitive_fields(item)


# ---------------------------------------------------------------------------
# Authorization Tests
# ---------------------------------------------------------------------------

def test_admin_catalogue_rejects_unauthenticated(client: TestClient) -> None:
    assert client.get("/api/v1/admin/catalogue/products").status_code == 401
    assert client.post("/api/v1/admin/catalogue/products", json={}).status_code == 401
    assert client.get("/api/v1/admin/catalogue/categories").status_code == 401
    assert client.post("/api/v1/admin/catalogue/categories", json={}).status_code == 401


@pytest.mark.parametrize("role", ["customer", "partner", "staff"])
def test_admin_catalogue_rejects_non_admin_roles(client: TestClient, role: str) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        user = _create_user(db, mobile=f"987654321{role[0]}", role=role)

    headers = _auth_header(user)
    assert client.get("/api/v1/admin/catalogue/products", headers=headers).status_code == 403
    assert client.post("/api/v1/admin/catalogue/products", json={}, headers=headers).status_code == 403
    assert client.get("/api/v1/admin/catalogue/categories", headers=headers).status_code == 403


def test_admin_catalogue_rejects_deactivated_admin(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db, is_active=False)

    headers = _auth_header(admin)
    assert client.get("/api/v1/admin/catalogue/products", headers=headers).status_code == 403


# ---------------------------------------------------------------------------
# Product Listing & Filtering Tests
# ---------------------------------------------------------------------------

def test_admin_products_pagination_and_sorting(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        cat = _create_category(db, name="Engine")
        for i in range(1, 26):
            _create_product(db, category=cat, product_code=f"ENG-{i:02d}", name=f"Part {i}")

    headers = _auth_header(admin)
    res = client.get("/api/v1/admin/catalogue/products", params={"page": 1, "page_size": 10}, headers=headers)
    assert res.status_code == 200
    data = res.json()

    assert data["total"] == 25
    assert data["page"] == 1
    assert data["page_size"] == 10
    assert data["total_pages"] == 3
    assert len(data["items"]) == 10
    # Stable id desc order
    assert data["items"][0]["product_code"] == "ENG-25"

    _assert_no_sensitive_fields(data)


def test_admin_products_search_and_filters(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        cat1 = _create_category(db, name="Brakes")
        cat2 = _create_category(db, name="Electrical")
        _create_product(db, category=cat1, product_code="BRK-100", name="Front Disc", vehicle_type="2-Wheeler", price=Decimal("800.00"), is_active=True)
        _create_product(db, category=cat1, product_code="BRK-200", name="Rear Drum", vehicle_type="3-Wheeler", price=Decimal("450.00"), is_active=False)
        _create_product(db, category=cat2, product_code="ELE-300", name="LED Bulb", vehicle_type="Both", price=None, is_active=True)

    headers = _auth_header(admin)

    # Filter by category
    res = client.get("/api/v1/admin/catalogue/products", params={"category_id": cat1.id}, headers=headers)
    assert res.json()["total"] == 2

    # Filter by vehicle_type
    res = client.get("/api/v1/admin/catalogue/products", params={"vehicle_type": "2-Wheeler"}, headers=headers)
    assert res.json()["total"] == 1
    assert res.json()["items"][0]["product_code"] == "BRK-100"

    # Filter by inactive status (Admin can see inactive!)
    res = client.get("/api/v1/admin/catalogue/products", params={"status": "inactive"}, headers=headers)
    assert res.json()["total"] == 1
    assert res.json()["items"][0]["product_code"] == "BRK-200"

    # Filter by missing price
    res = client.get("/api/v1/admin/catalogue/products", params={"has_price": False}, headers=headers)
    assert res.json()["total"] == 1
    assert res.json()["items"][0]["product_code"] == "ELE-300"
    assert res.json()["items"][0]["price"] is None

    # Search by code or description
    res = client.get("/api/v1/admin/catalogue/products", params={"search": "drum"}, headers=headers)
    assert res.json()["total"] == 1
    assert res.json()["items"][0]["name"] == "Rear Drum"


def test_admin_get_product_detail(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        cat = _create_category(db, name="Gears")
        prod = _create_product(db, category=cat, product_code="GR-01", name="Main Gear", is_active=False)

    headers = _auth_header(admin)
    res = client.get(f"/api/v1/admin/catalogue/products/{prod.id}", headers=headers)
    assert res.status_code == 200
    body = res.json()
    assert body["id"] == prod.id
    assert body["name"] == "Main Gear"
    assert body["category_name"] == "Gears"
    assert body["is_active"] is False

    # 404 for nonexistent product
    assert client.get("/api/v1/admin/catalogue/products/99999", headers=headers).status_code == 404


# ---------------------------------------------------------------------------
# Product Creation Tests
# ---------------------------------------------------------------------------

def test_admin_create_product_success_and_nullable_price(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        cat = _create_category(db, name="Filters")

    headers = _auth_header(admin)
    payload = {
        "product_code": "FLTR-001",
        "name": "Oil Filter Special",
        "category_id": cat.id,
        "vehicle_type": "2-Wheeler",
        "price": "120.50",
        "description": "High performance oil filter",
        "image_url": "https://example.com/filter.png",
        "is_active": True,
    }

    res = client.post("/api/v1/admin/catalogue/products", json=payload, headers=headers)
    assert res.status_code == 201
    data = res.json()
    assert data["product_code"] == "FLTR-001"
    assert data["name"] == "Oil Filter Special"
    assert data["price"] == "120.50"
    assert data["category_name"] == "Filters"
    assert data["is_active"] is True

    # Test creating product with NULL price
    null_price_payload = {
        "product_code": "FLTR-002",
        "name": "Custom Air Filter",
        "category_id": cat.id,
        "vehicle_type": "3-Wheeler",
        "price": None,
        "is_active": True,
    }
    null_res = client.post("/api/v1/admin/catalogue/products", json=null_price_payload, headers=headers)
    assert null_res.status_code == 201
    assert null_res.json()["price"] is None


def test_admin_create_product_allows_duplicate_codes(client: TestClient) -> None:
    """Duplicate product codes are permitted by the database schema and supplier catalogue rules."""
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        cat = _create_category(db, name="Clutch")

    headers = _auth_header(admin)
    payload1 = {
        "product_code": "CLT-DUP",
        "name": "Clutch Plate 2W",
        "category_id": cat.id,
        "vehicle_type": "2-Wheeler",
        "price": "350.00",
    }
    payload2 = {
        "product_code": "CLT-DUP",
        "name": "Clutch Plate 3W",
        "category_id": cat.id,
        "vehicle_type": "3-Wheeler",
        "price": "420.00",
    }

    assert client.post("/api/v1/admin/catalogue/products", json=payload1, headers=headers).status_code == 201
    res2 = client.post("/api/v1/admin/catalogue/products", json=payload2, headers=headers)
    assert res2.status_code == 201
    assert res2.json()["product_code"] == "CLT-DUP"


def test_admin_create_product_validations(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        cat = _create_category(db, name="Mirrors")

    headers = _auth_header(admin)

    # Negative price rejected
    bad_price = {
        "product_code": "MIR-01",
        "name": "Side Mirror",
        "category_id": cat.id,
        "vehicle_type": "2-Wheeler",
        "price": "-25.00",
    }
    assert client.post("/api/v1/admin/catalogue/products", json=bad_price, headers=headers).status_code == 422

    # Invalid vehicle type rejected
    bad_vt = {
        "product_code": "MIR-01",
        "name": "Side Mirror",
        "category_id": cat.id,
        "vehicle_type": "4-Wheeler",
        "price": "100.00",
    }
    assert client.post("/api/v1/admin/catalogue/products", json=bad_vt, headers=headers).status_code == 422

    # Nonexistent category returns 404
    bad_cat = {
        "product_code": "MIR-01",
        "name": "Side Mirror",
        "category_id": 99999,
        "vehicle_type": "2-Wheeler",
        "price": "100.00",
    }
    assert client.post("/api/v1/admin/catalogue/products", json=bad_cat, headers=headers).status_code == 404


# ---------------------------------------------------------------------------
# Product Update Tests
# ---------------------------------------------------------------------------

def test_admin_update_product_partial_and_explicit_null_price(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        cat = _create_category(db, name="Cables")
        prod = _create_product(
            db,
            category=cat,
            product_code="CBL-01",
            name="Throttle Cable",
            vehicle_type="2-Wheeler",
            price=Decimal("180.00"),
            description="Steel braided cable",
        )

    headers = _auth_header(admin)

    # 1. Partial update: change only name, leave price & description untouched
    update1 = client.post(
        f"/api/v1/admin/catalogue/products/{prod.id}/update",
        json={"name": "Reinforced Throttle Cable"},
        headers=headers,
    )
    assert update1.status_code == 200
    b1 = update1.json()
    assert b1["name"] == "Reinforced Throttle Cable"
    assert b1["price"] == "180.00"
    assert b1["description"] == "Steel braided cable"

    # 2. Explicitly clear price to null
    update2 = client.post(
        f"/api/v1/admin/catalogue/products/{prod.id}/update",
        json={"price": None},
        headers=headers,
    )
    assert update2.status_code == 200
    assert update2.json()["price"] is None
    assert update2.json()["name"] == "Reinforced Throttle Cable"

    # 3. Nonexistent product -> 404
    assert client.post("/api/v1/admin/catalogue/products/99999/update", json={"name": "X"}, headers=headers).status_code == 404


# ---------------------------------------------------------------------------
# Product Status & Public Catalogue Integration
# ---------------------------------------------------------------------------

def test_admin_product_status_toggle_and_public_visibility(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        cat = _create_category(db, name="Lighting")
        prod = _create_product(db, category=cat, product_code="LGT-01", name="LED Tail Light", is_active=True)

    headers = _auth_header(admin)

    # Initially public
    pub_res = client.get("/api/v1/products")
    assert any(p["id"] == prod.id for p in pub_res.json()["items"])
    assert client.get(f"/api/v1/products/{prod.id}").status_code == 200

    # Deactivate product via Admin API
    deact_res = client.post(
        f"/api/v1/admin/catalogue/products/{prod.id}/status",
        json={"is_active": False},
        headers=headers,
    )
    assert deact_res.status_code == 200
    assert deact_res.json()["is_active"] is False

    # Verify disappeared from public catalogue listing and details
    pub_after = client.get("/api/v1/products")
    assert not any(p["id"] == prod.id for p in pub_after.json()["items"])
    assert client.get(f"/api/v1/products/{prod.id}").status_code == 404

    # Admin can still view it
    admin_detail = client.get(f"/api/v1/admin/catalogue/products/{prod.id}", headers=headers)
    assert admin_detail.status_code == 200
    assert admin_detail.json()["is_active"] is False

    # Reactivate product
    act_res = client.post(
        f"/api/v1/admin/catalogue/products/{prod.id}/status",
        json={"is_active": True},
        headers=headers,
    )
    assert act_res.status_code == 200
    assert act_res.json()["is_active"] is True

    # Reappears in public catalogue
    assert client.get(f"/api/v1/products/{prod.id}").status_code == 200


# ---------------------------------------------------------------------------
# Category Endpoints Tests
# ---------------------------------------------------------------------------

def test_admin_category_listing_with_product_counts(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        cat_active = _create_category(db, name="Batteries", is_active=True)
        cat_inactive = _create_category(db, name="Old Stock", is_active=False)
        _create_product(db, category=cat_active, product_code="BAT-01", name="12V Battery")
        _create_product(db, category=cat_active, product_code="BAT-02", name="6V Battery")

    headers = _auth_header(admin)
    res = client.get("/api/v1/admin/catalogue/categories", headers=headers)
    assert res.status_code == 200
    categories = res.json()

    # Admin sees both active and inactive
    names = [c["name"] for c in categories]
    assert "Batteries" in names
    assert "Old Stock" in names

    # Check computed product count
    battery_cat = next(c for c in categories if c["name"] == "Batteries")
    assert battery_cat["product_count"] == 2

    old_stock_cat = next(c for c in categories if c["name"] == "Old Stock")
    assert old_stock_cat["product_count"] == 0


def test_admin_create_category_and_duplicate_handling(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        _create_category(db, name="Sensors")

    headers = _auth_header(admin)

    # Success
    res = client.post(
        "/api/v1/admin/catalogue/categories",
        json={"name": "Suspension", "description": "Shock absorbers and forks"},
        headers=headers,
    )
    assert res.status_code == 201
    assert res.json()["name"] == "Suspension"
    assert res.json()["product_count"] == 0

    # Duplicate name conflict (case-insensitive) -> 409
    dup_res = client.post(
        "/api/v1/admin/catalogue/categories",
        json={"name": "sensors"},
        headers=headers,
    )
    assert dup_res.status_code == 409
    assert "already exists" in dup_res.json()["detail"].lower()


def test_admin_category_status_toggle_cascades_to_public_catalogue(client: TestClient) -> None:
    """When a category is deactivated, its products must disappear from public endpoints."""
    with next(app.dependency_overrides[get_db]()) as db:
        admin = _create_user(db)
        cat = _create_category(db, name="Exhausts", is_active=True)
        prod = _create_product(db, category=cat, product_code="EXH-01", name="Muffler", is_active=True)

    headers = _auth_header(admin)

    # Deactivate category
    deact_cat = client.post(
        f"/api/v1/admin/catalogue/categories/{cat.id}/status",
        json={"is_active": False},
        headers=headers,
    )
    assert deact_cat.status_code == 200
    assert deact_cat.json()["is_active"] is False

    # Public category listing excludes it
    pub_cats = client.get("/api/v1/categories")
    assert not any(c["id"] == cat.id for c in pub_cats.json())

    # Public product listing excludes product assigned to deactivated category
    pub_prods = client.get("/api/v1/products")
    assert not any(p["id"] == prod.id for p in pub_prods.json()["items"])

    # Public product detail returns 404
    assert client.get(f"/api/v1/products/{prod.id}").status_code == 404

    # Admin endpoints still view both
    admin_prod = client.get(f"/api/v1/admin/catalogue/products/{prod.id}", headers=headers)
    assert admin_prod.status_code == 200
    assert admin_prod.json()["category_is_active"] is False
