from collections.abc import Generator
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.security import create_access_token
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models import Product, ProductCategory, User


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(
        bind=engine,
        tables=[ProductCategory.__table__, Product.__table__, User.__table__],
    )

    def override_get_db() -> Generator[Session, None, None]:
        with Session(engine) as db:
            yield db

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)
    engine.dispose()


def test_new_arrivals_empty_database_returns_empty_list(client: TestClient) -> None:
    response = client.get("/api/v1/products/new-arrivals")
    assert response.status_code == 200
    assert response.json() == []


def test_new_arrivals_returns_latest_sorted_newest_first_up_to_five(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        category = ProductCategory(id=1, name="Engine Parts", is_active=True)
        db.add(category)
        db.flush()

        for i in range(1, 8):
            db.add(
                Product(
                    id=i,
                    category_id=category.id,
                    product_code=f"PROD-{i:03d}",
                    name=f"Product Item {i}",
                    description=f"Description for item {i}",
                    vehicle_type="2-Wheeler" if i % 2 == 1 else "3-Wheeler",
                    price=Decimal(f"{100 + i}.50"),
                    image_url=f"https://example.com/images/prod_{i}.png",
                    is_active=True,
                )
            )
        db.commit()

    response = client.get("/api/v1/products/new-arrivals")
    assert response.status_code == 200
    items = response.json()

    # Enforce maximum of 5 products
    assert len(items) == 5
    # Verify sorted newest first (Product 7, 6, 5, 4, 3)
    expected_ids = [7, 6, 5, 4, 3]
    assert [p["id"] for p in items] == expected_ids
    assert items[0]["name"] == "Product Item 7"
    assert items[0]["product_code"] == "PROD-007"
    assert items[0]["category_name"] == "Engine Parts"
    assert items[0]["vehicle_type"] == "2-Wheeler"
    assert items[0]["price"] == "107.50"
    assert items[0]["image_url"] == "https://example.com/images/prod_7.png"


def test_new_arrivals_drops_oldest_when_new_product_is_added(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        cat = ProductCategory(id=1, name="Brakes", is_active=True)
        db.add(cat)
        db.flush()

        for i in range(1, 6):
            db.add(
                Product(
                    id=i,
                    category_id=cat.id,
                    product_code=f"BRK-{i}",
                    name=f"Brake Item {i}",
                    vehicle_type="Both",
                    price=Decimal("200.00"),
                    is_active=True,
                )
            )
        db.commit()

    # Initial 5 products: 5, 4, 3, 2, 1
    res1 = client.get("/api/v1/products/new-arrivals")
    assert res1.status_code == 200
    assert [p["id"] for p in res1.json()] == [5, 4, 3, 2, 1]

    # Add a 6th product
    with next(app.dependency_overrides[get_db]()) as db:
        db.add(
            Product(
                id=6,
                category_id=1,
                product_code="BRK-6",
                name="Brake Item 6 (Brand New)",
                vehicle_type="Both",
                price=Decimal("250.00"),
                is_active=True,
            )
        )
        db.commit()

    # Now product 6 appears at top, product 1 drops off
    res2 = client.get("/api/v1/products/new-arrivals")
    assert res2.status_code == 200
    items2 = res2.json()
    assert len(items2) == 5
    assert [p["id"] for p in items2] == [6, 5, 4, 3, 2]
    assert items2[0]["name"] == "Brake Item 6 (Brand New)"


def test_new_arrivals_filters_inactive_products_and_inactive_categories(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        active_cat = ProductCategory(id=1, name="Active Category", is_active=True)
        inactive_cat = ProductCategory(id=2, name="Inactive Category", is_active=False)
        db.add_all([active_cat, inactive_cat])
        db.flush()

        db.add_all(
            [
                Product(
                    id=1,
                    category_id=active_cat.id,
                    product_code="ACTIVE-1",
                    name="Visible Product 1",
                    vehicle_type="2-Wheeler",
                    price=Decimal("50.00"),
                    is_active=True,
                ),
                Product(
                    id=2,
                    category_id=active_cat.id,
                    product_code="INACTIVE-PROD",
                    name="Inactive Product",
                    vehicle_type="2-Wheeler",
                    price=Decimal("60.00"),
                    is_active=False,
                ),
                Product(
                    id=3,
                    category_id=inactive_cat.id,
                    product_code="INACTIVE-CAT",
                    name="Product in Inactive Category",
                    vehicle_type="2-Wheeler",
                    price=Decimal("70.00"),
                    is_active=True,
                ),
                Product(
                    id=4,
                    category_id=active_cat.id,
                    product_code="ACTIVE-2",
                    name="Visible Product 2",
                    vehicle_type="2-Wheeler",
                    price=Decimal("80.00"),
                    is_active=True,
                ),
            ]
        )
        db.commit()

    response = client.get("/api/v1/products/new-arrivals")
    assert response.status_code == 200
    items = response.json()
    assert len(items) == 2
    assert [p["id"] for p in items] == [4, 1]


def test_new_arrivals_returns_available_when_fewer_than_five(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        cat = ProductCategory(id=1, name="Lighting", is_active=True)
        db.add(cat)
        db.flush()

        db.add_all(
            [
                Product(
                    id=1,
                    category_id=cat.id,
                    product_code="LIGHT-1",
                    name="Headlight Bulb",
                    vehicle_type="2-Wheeler",
                    price=Decimal("120.00"),
                    is_active=True,
                ),
                Product(
                    id=2,
                    category_id=cat.id,
                    product_code="LIGHT-2",
                    name="Tail Light Bulb",
                    vehicle_type="2-Wheeler",
                    price=Decimal("80.00"),
                    is_active=True,
                ),
            ]
        )
        db.commit()

    response = client.get("/api/v1/products/new-arrivals")
    assert response.status_code == 200
    items = response.json()
    assert len(items) == 2
    assert [p["id"] for p in items] == [2, 1]


def test_new_arrivals_custom_limit_enforced_and_validated(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        cat = ProductCategory(id=1, name="Suspension", is_active=True)
        db.add(cat)
        db.flush()

        for i in range(1, 6):
            db.add(
                Product(
                    id=i,
                    category_id=cat.id,
                    product_code=f"SHK-{i}",
                    name=f"Shock {i}",
                    vehicle_type="Both",
                    price=Decimal("500.00"),
                    is_active=True,
                )
            )
        db.commit()

    # Explicit limit=3
    res_3 = client.get("/api/v1/products/new-arrivals?limit=3")
    assert res_3.status_code == 200
    assert len(res_3.json()) == 3
    assert [p["id"] for p in res_3.json()] == [5, 4, 3]

    # Limit > 5 is rejected by validation (422)
    res_over = client.get("/api/v1/products/new-arrivals?limit=6")
    assert res_over.status_code == 422

    # Limit < 1 is rejected by validation (422)
    res_under = client.get("/api/v1/products/new-arrivals?limit=0")
    assert res_under.status_code == 422


def test_new_arrivals_list_price_visibility_based_on_role(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        cat = ProductCategory(id=1, name="Tyres", is_active=True)
        db.add(cat)
        db.flush()

        db.add(
            Product(
                id=1,
                category_id=cat.id,
                product_code="TYRE-01",
                name="Tubeless Tyre",
                vehicle_type="2-Wheeler",
                price=Decimal("1500.00"),
                list_price=Decimal("1200.00"),
                is_active=True,
            )
        )

        partner_user = User(
            id=10,
            mobile="9800000001",
            name="Partner User",
            password_hash="fakehash",
            role="partner",
            is_active=True,
        )
        staff_user = User(
            id=11,
            mobile="9800000002",
            name="Staff User",
            password_hash="fakehash",
            role="staff",
            is_active=True,
        )
        customer_user = User(
            id=12,
            mobile="9800000003",
            name="Customer User",
            password_hash="fakehash",
            role="customer",
            is_active=True,
        )
        db.add_all([partner_user, staff_user, customer_user])
        db.commit()

    # 1. Unauthenticated / Customer cannot see list_price
    public_res = client.get("/api/v1/products/new-arrivals")
    assert public_res.status_code == 200
    assert "list_price" not in public_res.json()[0] or public_res.json()[0]["list_price"] is None

    customer_token = create_access_token(subject="12", role="customer")
    cust_res = client.get(
        "/api/v1/products/new-arrivals",
        headers={"Authorization": f"Bearer {customer_token}"},
    )
    assert cust_res.status_code == 200
    assert "list_price" not in cust_res.json()[0] or cust_res.json()[0]["list_price"] is None

    # 2. Partner sees list_price
    partner_token = create_access_token(subject="10", role="partner")
    part_res = client.get(
        "/api/v1/products/new-arrivals",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert part_res.status_code == 200
    assert part_res.json()[0]["list_price"] == "1200.00"

    # 3. Staff sees list_price
    staff_token = create_access_token(subject="11", role="staff")
    staff_res = client.get(
        "/api/v1/products/new-arrivals",
        headers={"Authorization": f"Bearer {staff_token}"},
    )
    assert staff_res.status_code == 200
    assert staff_res.json()[0]["list_price"] == "1200.00"
