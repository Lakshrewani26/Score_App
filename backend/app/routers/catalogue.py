from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import Product, ProductCategory
from app.schemas.catalogue import (
    CategoryResponse,
    ProductListResponse,
    ProductPagination,
    ProductResponse,
)

router = APIRouter(prefix="/api/v1", tags=["catalogue"])


def _product_response(product: Product, category_name: str | None) -> ProductResponse:
    return ProductResponse(
        id=product.id,
        category_id=product.category_id,
        category_name=category_name,
        product_code=product.product_code,
        name=product.name,
        description=product.description,
        vehicle_type=product.vehicle_type,
        price=product.price,
        image_url=product.image_url,
    )


@router.get("/categories", response_model=list[CategoryResponse])
def list_categories(db: Session = Depends(get_db)) -> list[CategoryResponse]:
    categories = db.scalars(
        select(ProductCategory)
        .where(ProductCategory.is_active.is_(True))
        .order_by(ProductCategory.name, ProductCategory.id)
    ).all()
    return [
        CategoryResponse(
            id=category.id,
            name=category.name,
            description=category.description,
        )
        for category in categories
    ]


@router.get("/products", response_model=ProductListResponse)
def list_products(
    category_id: int | None = Query(default=None, ge=1),
    vehicle_type: Literal["2-Wheeler", "3-Wheeler", "Both"] | None = None,
    search: str | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> ProductListResponse:
    filters = [
        Product.is_active.is_(True),
        ProductCategory.is_active.is_(True),
    ]
    if category_id is not None:
        filters.append(Product.category_id == category_id)
    if vehicle_type is not None:
        filters.append(Product.vehicle_type == vehicle_type)
    if search:
        pattern = f"%{search}%"
        filters.append(
            Product.name.ilike(pattern)
            | Product.product_code.ilike(pattern)
            | Product.description.ilike(pattern)
        )

    total = (
        db.scalar(
            select(func.count())
            .select_from(Product)
            .join(ProductCategory, Product.category_id == ProductCategory.id)
            .where(*filters)
        )
        or 0
    )
    product_rows = db.execute(
        select(Product, ProductCategory.name)
        .join(ProductCategory, Product.category_id == ProductCategory.id)
        .where(*filters)
        .order_by(Product.id)
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()

    return ProductListResponse(
        items=[
            _product_response(product, category_name)
            for product, category_name in product_rows
        ],
        pagination=ProductPagination(
            total=total,
            page=page,
            page_size=page_size,
            total_pages=(total + page_size - 1) // page_size,
        ),
    )


@router.get("/products/{product_id}", response_model=ProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)) -> ProductResponse:
    product_row = db.execute(
        select(Product, ProductCategory.name)
        .join(ProductCategory, Product.category_id == ProductCategory.id)
        .where(
            Product.id == product_id,
            Product.is_active.is_(True),
            ProductCategory.is_active.is_(True),
        )
    ).first()
    if product_row is None:
        raise HTTPException(status_code=404, detail="Product not found")

    product, category_name = product_row
    return _product_response(product, category_name)
