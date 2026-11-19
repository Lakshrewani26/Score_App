from collections.abc import Generator
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models import Product, ProductCategory


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(
        bind=engine,
        tables=[ProductCategory.__table__, Product.__table__],
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


def test_categories_lists_only_active_in_stable_order(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        db.add_all(
            [
                ProductCategory(id=2, name="Zeta", is_active=True),
                ProductCategory(id=1, name="Alpha", is_active=True),
                ProductCategory(id=3, name="Hidden", is_active=False),
            ]
        )
        db.commit()

    response = client.get("/api/v1/categories")

    assert response.status_code == 200
    assert [category["name"] for category in response.json()] == ["Alpha", "Zeta"]


def test_products_filters_before_pagination_and_keeps_decimal_price(
    client: TestClient,
) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        category = ProductCategory(id=1, name="Parts", is_active=True)
        db.add(category)
        db.add_all(
            [
                Product(
                    id=1,
                    category=category,
                    product_code="MATCH-1",
                    name="Brake lever",
                    description="Front part",
                    package_quantity="10 PC",
                    vehicle_type="2-Wheeler",
                    price=Decimal("12.30"),
                    is_active=True,
                ),
                Product(
                    id=2,
                    category=category,
                    product_code="MATCH-2",
                    name="Brake cable",
                    description=None,
                    vehicle_type="3-Wheeler",
                    price=Decimal("25.00"),
                    is_active=True,
                ),
                Product(
                    id=3,
                    category=category,
                    product_code="INACTIVE",
                    name="Brake pad",
                    description=None,
                    vehicle_type="2-Wheeler",
                    price=Decimal("1.00"),
                    is_active=False,
                ),
                Product(
                    id=4,
                    category=category,
                    product_code="MATCH-4",
                    name="Front tyre",
                    description=None,
                    vehicle_type="2-Wheeler",
                    price=Decimal("32.00"),
                    is_active=True,
                ),
            ]
        )
        db.commit()

    response = client.get(
        "/api/v1/products",
        params={
            "category_id": 1,
            "vehicle_type": "2-Wheeler",
            "search": "front",
            "page": 1,
            "page_size": 1,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert [product["id"] for product in body["items"]] == [1]
    assert body["items"][0]["category_name"] == "Parts"
    assert body["items"][0]["package_quantity"] == "10 PC"
    assert body["items"][0]["price"] == "12.30"
    assert body["pagination"] == {
        "total": 2,
        "page": 1,
        "page_size": 1,
        "total_pages": 2,
    }

    second_page = client.get(
        "/api/v1/products",
        params={
            "category_id": 1,
            "vehicle_type": "2-Wheeler",
            "search": "front",
            "page": 2,
            "page_size": 1,
        },
    )
    assert [product["id"] for product in second_page.json()["items"]] == [4]


def test_categories_returns_empty_array_when_none_are_active(client: TestClient) -> None:
    assert client.get("/api/v1/categories").json() == []


@pytest.mark.parametrize(
    ("params", "invalid_path"),
    [
        ({"category_id": 0}, "/api/v1/products"),
        ({"vehicle_type": "4-Wheeler"}, "/api/v1/products"),
        ({"page": 0}, "/api/v1/products"),
        ({"page_size": 101}, "/api/v1/products"),
    ],
)
def test_products_rejects_invalid_query_parameters(
    client: TestClient,
    params: dict[str, str | int],
    invalid_path: str,
) -> None:
    response = client.get(invalid_path, params=params)

    assert response.status_code == 422


def test_product_detail_returns_404_for_missing_or_inactive_products(
    client: TestClient,
) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        category = ProductCategory(id=1, name="Parts", is_active=True)
        db.add(category)
        db.add(
            Product(
                id=1,
                category=category,
                product_code="INACTIVE",
                name="Hidden item",
                vehicle_type="Both",
                price=Decimal("0.00"),
                is_active=False,
            )
        )
        db.commit()

    assert client.get("/api/v1/products/1").status_code == 404
    assert client.get("/api/v1/products/999").status_code == 404


def test_product_detail_returns_public_product_fields(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        category = ProductCategory(id=1, name="Parts", is_active=True)
        db.add(category)
        db.add(
            Product(
                id=1,
                category=category,
                product_code="PART-001",
                name="Brake lever",
                description="Front part",
                package_quantity="15 PC",
                vehicle_type="2-Wheeler",
                price=Decimal("12.30"),
                image_url=None,
                is_active=True,
            )
        )
        db.commit()

    response = client.get("/api/v1/products/1")

    assert response.status_code == 200
    assert response.json() == {
        "id": 1,
        "category_id": 1,
        "category_name": "Parts",
        "product_code": "PART-001",
        "name": "Brake lever",
        "description": "Front part",
        "package_quantity": "15 PC",
        "vehicle_type": "2-Wheeler",
        "price": "12.30",
        "image_url": None,
    }


def test_products_with_null_price_serializes_successfully_regression(
    client: TestClient,
) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        category = ProductCategory(id=10, name="Accessories", is_active=True)
        db.add(category)
        db.add(
            Product(
                id=100,
                category=category,
                product_code="UNPRICED-01",
                name="Special Sticker",
                description="Promotional sticker",
                vehicle_type="Both",
                price=None,
                image_url=None,
                is_active=True,
            )
        )
        db.commit()

    # Verify listing serializes price as null without HTTP 500
    list_res = client.get("/api/v1/products", params={"category_id": 10})
    assert list_res.status_code == 200
    data = list_res.json()
    assert len(data["items"]) == 1
    assert data["items"][0]["id"] == 100
    assert data["items"][0]["price"] is None
    assert data["items"][0]["package_quantity"] is None
    assert data["items"][0]["category_name"] == "Accessories"

    # Verify single product detail endpoint also serializes price as null
    detail_res = client.get("/api/v1/products/100")
    assert detail_res.status_code == 200
    assert detail_res.json()["price"] is None
    assert detail_res.json()["package_quantity"] is None
    assert detail_res.json()["product_code"] == "UNPRICED-01"


def test_products_assigned_to_inactive_category_are_excluded_from_public_catalogue(
    client: TestClient,
) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        active_cat = ProductCategory(id=20, name="Active Category", is_active=True)
        inactive_cat = ProductCategory(id=21, name="Inactive Category", is_active=False)
        db.add_all([active_cat, inactive_cat])
        db.add_all(
            [
                Product(
                    id=201,
                    category=active_cat,
                    product_code="ACT-01",
                    name="Visible Part",
                    vehicle_type="2-Wheeler",
                    price=Decimal("50.00"),
                    is_active=True,
                ),
                Product(
                    id=202,
                    category=inactive_cat,
                    product_code="INACT-01",
                    name="Hidden Due to Category",
                    vehicle_type="2-Wheeler",
                    price=Decimal("60.00"),
                    is_active=True,
                ),
            ]
        )
        db.commit()

    # Public category listing should exclude inactive category
    cat_res = client.get("/api/v1/categories")
    assert cat_res.status_code == 200
    category_names = [c["name"] for c in cat_res.json()]
    assert "Active Category" in category_names
    assert "Inactive Category" not in category_names

    # Public product listing should only include products from active categories
    prod_res = client.get("/api/v1/products")
    assert prod_res.status_code == 200
    product_ids = [p["id"] for p in prod_res.json()["items"]]
    assert 201 in product_ids
    assert 202 not in product_ids

    # Public product detail for product in inactive category should return 404
    assert client.get("/api/v1/products/201").status_code == 200
    assert client.get("/api/v1/products/202").status_code == 404


def test_categories_filtered_by_vehicle_type(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        cat_2w = ProductCategory(id=30, name="2W Only Category", is_active=True)
        cat_3w = ProductCategory(id=31, name="3W Only Category", is_active=True)
        cat_both = ProductCategory(id=32, name="Both Category", is_active=True)
        cat_empty = ProductCategory(id=33, name="Empty Active Category", is_active=True)
        cat_inactive = ProductCategory(id=34, name="Inactive 2W Category", is_active=False)
        db.add_all([cat_2w, cat_3w, cat_both, cat_empty, cat_inactive])
        db.add_all(
            [
                Product(
                    id=301,
                    category=cat_2w,
                    product_code="P2W-1",
                    name="2W Product 1",
                    vehicle_type="2-Wheeler",
                    price=Decimal("100.00"),
                    is_active=True,
                ),
                Product(
                    id=302,
                    category=cat_2w,
                    product_code="P2W-2",
                    name="2W Product 2",
                    vehicle_type="2-Wheeler",
                    price=Decimal("150.00"),
                    is_active=True,
                ),
                Product(
                    id=303,
                    category=cat_3w,
                    product_code="P3W-1",
                    name="3W Product 1",
                    vehicle_type="3-Wheeler",
                    price=Decimal("200.00"),
                    is_active=True,
                ),
                Product(
                    id=304,
                    category=cat_both,
                    product_code="PBOTH-1",
                    name="Both Product 1",
                    vehicle_type="Both",
                    price=Decimal("50.00"),
                    is_active=True,
                ),
                Product(
                    id=305,
                    category=cat_inactive,
                    product_code="PINACT-1",
                    name="Inactive Category Product",
                    vehicle_type="2-Wheeler",
                    price=Decimal("75.00"),
                    is_active=True,
                ),
                Product(
                    id=306,
                    category=cat_2w,
                    product_code="PINACT-PROD",
                    name="Inactive Product in 2W",
                    vehicle_type="2-Wheeler",
                    price=Decimal("80.00"),
                    is_active=False,
                ),
            ]
        )
        db.commit()

    # 1. 2-Wheeler query returns only 2W and Both categories, no duplicates, alphabetical
    res_2w = client.get("/api/v1/categories", params={"vehicle_type": "2-Wheeler"})
    assert res_2w.status_code == 200
    names_2w = [c["name"] for c in res_2w.json()]
    assert names_2w == ["2W Only Category", "Both Category"]

    # 2. 3-Wheeler query returns only 3W and Both categories, no duplicates, alphabetical
    res_3w = client.get("/api/v1/categories", params={"vehicle_type": "3-Wheeler"})
    assert res_3w.status_code == 200
    names_3w = [c["name"] for c in res_3w.json()]
    assert names_3w == ["3W Only Category", "Both Category"]

    # 3. No vehicle_type filter returns all active categories (including empty ones)
    res_all = client.get("/api/v1/categories")
    assert res_all.status_code == 200
    names_all = [c["name"] for c in res_all.json()]
    assert "2W Only Category" in names_all
    assert "3W Only Category" in names_all
    assert "Both Category" in names_all
    assert "Empty Active Category" in names_all
    assert "Inactive 2W Category" not in names_all

    # 4. Invalid vehicle_type query param returns 422
    res_invalid = client.get("/api/v1/categories", params={"vehicle_type": "4-Wheeler"})
    assert res_invalid.status_code == 422


def test_products_filtered_by_vehicle_type_includes_both(client: TestClient) -> None:
    with next(app.dependency_overrides[get_db]()) as db:
        cat = ProductCategory(id=40, name="Universal Parts", is_active=True)
        db.add(cat)
        db.add_all(
            [
                Product(
                    id=401,
                    category=cat,
                    product_code="P-2W",
                    name="2W Only Part",
                    vehicle_type="2-Wheeler",
                    price=Decimal("100.00"),
                    is_active=True,
                ),
                Product(
                    id=402,
                    category=cat,
                    product_code="P-3W",
                    name="3W Only Part",
                    vehicle_type="3-Wheeler",
                    price=Decimal("200.00"),
                    is_active=True,
                ),
                Product(
                    id=403,
                    category=cat,
                    product_code="P-BOTH",
                    name="Universal Part",
                    vehicle_type="Both",
                    price=Decimal("150.00"),
                    is_active=True,
                ),
                Product(
                    id=404,
                    category=cat,
                    product_code="P-INACTIVE",
                    name="Inactive Universal Part",
                    vehicle_type="Both",
                    price=Decimal("150.00"),
                    is_active=False,
                ),
            ]
        )
        db.commit()

    # 1. 2-Wheeler query includes 2W and Both, excludes 3W and inactive
    res_2w = client.get("/api/v1/products", params={"vehicle_type": "2-Wheeler"})
    assert res_2w.status_code == 200
    items_2w = res_2w.json()["items"]
    codes_2w = [p["product_code"] for p in items_2w]
    assert "P-2W" in codes_2w
    assert "P-BOTH" in codes_2w
    assert "P-3W" not in codes_2w
    assert "P-INACTIVE" not in codes_2w

    # 2. 3-Wheeler query includes 3W and Both, excludes 2W and inactive
    res_3w = client.get("/api/v1/products", params={"vehicle_type": "3-Wheeler"})
    assert res_3w.status_code == 200
    items_3w = res_3w.json()["items"]
    codes_3w = [p["product_code"] for p in items_3w]
    assert "P-3W" in codes_3w
    assert "P-BOTH" in codes_3w
    assert "P-2W" not in codes_3w
    assert "P-INACTIVE" not in codes_3w

    # 3. Both query includes only Both active products
    res_both = client.get("/api/v1/products", params={"vehicle_type": "Both"})
    assert res_both.status_code == 200
    items_both = res_both.json()["items"]
    codes_both = [p["product_code"] for p in items_both]
    assert codes_both == ["P-BOTH"]
