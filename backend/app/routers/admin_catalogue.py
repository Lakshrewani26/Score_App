from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import require_admin
from app.db.session import get_db
from app.models import Product, ProductCategory, User
from app.schemas.admin_catalogue import (
    AdminCategoryCreateRequest,
    AdminCategoryResponse,
    AdminProductCreateRequest,
    AdminProductListResponse,
    AdminProductPagination,
    AdminProductResponse,
    AdminProductUpdateRequest,
    CategoryStatusUpdateRequest,
    ProductStatusUpdateRequest,
)

router = APIRouter(prefix="/api/v1/admin/catalogue", tags=["admin-catalogue"])


# ---------------------------------------------------------------------------
# Product Endpoints
# ---------------------------------------------------------------------------

@router.get("/products", response_model=AdminProductListResponse)
def list_admin_products(
    category_id: int | None = Query(default=None, ge=1),
    vehicle_type: Literal["2-Wheeler", "3-Wheeler", "Both"] | None = Query(default=None),
    search: str | None = Query(default=None),
    status_filter: Literal["all", "active", "inactive"] | None = Query(default=None, alias="status"),
    is_active: bool | None = Query(default=None),
    has_price: bool | None = Query(default=None),
    price_missing: bool | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminProductListResponse:
    """
    List products for Admin with multi-field search, category/vehicle filtering,
    active/inactive status filtering, missing price filtering, and pagination.
    Uses eager-loading/JOIN to prevent N+1 query overhead.
    """
    filters = []

    # Active status filter
    if status_filter == "active" or is_active is True:
        filters.append(Product.is_active.is_(True))
    elif status_filter == "inactive" or is_active is False:
        filters.append(Product.is_active.is_(False))
    # If "all" or None, include both active and inactive

    # Price missing filter
    if has_price is True or price_missing is False:
        filters.append(Product.price.is_not(None))
    elif has_price is False or price_missing is True:
        filters.append(Product.price.is_(None))

    if category_id is not None:
        filters.append(Product.category_id == category_id)

    if vehicle_type is not None:
        filters.append(Product.vehicle_type == vehicle_type)

    if search:
        clean_search = search.strip()
        if clean_search:
            pattern = f"%{clean_search}%"
            filters.append(
                Product.name.ilike(pattern)
                | Product.product_code.ilike(pattern)
                | Product.description.ilike(pattern)
            )

    total = db.scalar(
        select(func.count())
        .select_from(Product)
        .where(*filters)
    ) or 0

    total_pages = (total + page_size - 1) // page_size if total > 0 else 0
    offset = (page - 1) * page_size

    product_rows = db.execute(
        select(Product, ProductCategory.name, ProductCategory.is_active)
        .join(ProductCategory, Product.category_id == ProductCategory.id)
        .where(*filters)
        .order_by(Product.id.desc())
        .offset(offset)
        .limit(page_size)
    ).all()

    items = [
        AdminProductResponse(
            id=p.id,
            product_code=p.product_code,
            name=p.name,
            category_id=p.category_id,
            category_name=cat_name,
            category_is_active=cat_active,
            vehicle_type=p.vehicle_type,
            price=p.price,
            description=p.description,
            image_url=p.image_url,
            is_active=p.is_active,
        )
        for p, cat_name, cat_active in product_rows
    ]

    pagination = AdminProductPagination(
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )

    return AdminProductListResponse(
        items=items,
        pagination=pagination,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )


@router.get("/products/{product_id}", response_model=AdminProductResponse)
def get_admin_product_detail(
    product_id: int,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminProductResponse:
    """
    Retrieve product details for Admin. Allows viewing both active and inactive products.
    """
    row = db.execute(
        select(Product, ProductCategory.name, ProductCategory.is_active)
        .join(ProductCategory, Product.category_id == ProductCategory.id)
        .where(Product.id == product_id)
    ).first()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )

    product, cat_name, cat_active = row
    return AdminProductResponse(
        id=product.id,
        product_code=product.product_code,
        name=product.name,
        category_id=product.category_id,
        category_name=cat_name,
        category_is_active=cat_active,
        vehicle_type=product.vehicle_type,
        price=product.price,
        description=product.description,
        image_url=product.image_url,
        is_active=product.is_active,
    )


@router.post(
    "/products",
    response_model=AdminProductResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_product(
    payload: AdminProductCreateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminProductResponse:
    """
    Create a new product.
    Validates category existence and vehicle type.
    Allows duplicate product codes per database design.
    """
    category = db.get(ProductCategory, payload.category_id)
    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Category with ID {payload.category_id} not found",
        )

    product = Product(
        product_code=payload.product_code,
        name=payload.name,
        category_id=payload.category_id,
        vehicle_type=payload.vehicle_type,
        price=payload.price,
        description=payload.description.strip() if payload.description else None,
        image_url=payload.image_url.strip() if payload.image_url else None,
        is_active=payload.is_active,
    )

    db.add(product)
    db.commit()
    db.refresh(product)

    return AdminProductResponse(
        id=product.id,
        product_code=product.product_code,
        name=product.name,
        category_id=product.category_id,
        category_name=category.name,
        category_is_active=category.is_active,
        vehicle_type=product.vehicle_type,
        price=product.price,
        description=product.description,
        image_url=product.image_url,
        is_active=product.is_active,
    )


@router.post("/products/{product_id}/update", response_model=AdminProductResponse)
def update_product(
    product_id: int,
    payload: AdminProductUpdateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminProductResponse:
    """
    Update editable product fields.
    Uses exclude_unset to distinguish omitted fields from explicitly provided None values
    (e.g., explicitly setting price to NULL).
    """
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )

    update_data = payload.model_dump(exclude_unset=True)

    if "category_id" in update_data:
        target_cat = db.get(ProductCategory, update_data["category_id"])
        if target_cat is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Category with ID {update_data['category_id']} not found",
            )

    if "product_code" in update_data:
        product.product_code = update_data["product_code"]
    if "name" in update_data:
        product.name = update_data["name"]
    if "category_id" in update_data:
        product.category_id = update_data["category_id"]
    if "vehicle_type" in update_data:
        product.vehicle_type = update_data["vehicle_type"]
    if "price" in update_data:
        product.price = update_data["price"]
    if "description" in update_data:
        desc = update_data["description"]
        product.description = desc.strip() if desc else None
    if "image_url" in update_data:
        img = update_data["image_url"]
        product.image_url = img.strip() if img else None
    if "is_active" in update_data:
        product.is_active = update_data["is_active"]

    db.commit()
    db.refresh(product)

    cat = db.get(ProductCategory, product.category_id)
    return AdminProductResponse(
        id=product.id,
        product_code=product.product_code,
        name=product.name,
        category_id=product.category_id,
        category_name=cat.name if cat else None,
        category_is_active=cat.is_active if cat else True,
        vehicle_type=product.vehicle_type,
        price=product.price,
        description=product.description,
        image_url=product.image_url,
        is_active=product.is_active,
    )


@router.post("/products/{product_id}/status", response_model=AdminProductResponse)
def update_product_status(
    product_id: int,
    payload: ProductStatusUpdateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminProductResponse:
    """
    Activate or deactivate a product. Soft-toggle only; never hard-deletes.
    """
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )

    product.is_active = payload.is_active
    db.commit()
    db.refresh(product)

    cat = db.get(ProductCategory, product.category_id)
    return AdminProductResponse(
        id=product.id,
        product_code=product.product_code,
        name=product.name,
        category_id=product.category_id,
        category_name=cat.name if cat else None,
        category_is_active=cat.is_active if cat else True,
        vehicle_type=product.vehicle_type,
        price=product.price,
        description=product.description,
        image_url=product.image_url,
        is_active=product.is_active,
    )


# ---------------------------------------------------------------------------
# Category Endpoints
# ---------------------------------------------------------------------------

@router.get("/categories", response_model=list[AdminCategoryResponse])
def list_admin_categories(
    status_filter: Literal["all", "active", "inactive"] | None = Query(default=None, alias="status"),
    is_active: bool | None = Query(default=None),
    search: str | None = Query(default=None),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> list[AdminCategoryResponse]:
    """
    List all categories for Admin (active and inactive) along with the computed product count.
    """
    filters = []

    if status_filter == "active" or is_active is True:
        filters.append(ProductCategory.is_active.is_(True))
    elif status_filter == "inactive" or is_active is False:
        filters.append(ProductCategory.is_active.is_(False))

    if search:
        clean_search = search.strip()
        if clean_search:
            pattern = f"%{clean_search}%"
            filters.append(
                ProductCategory.name.ilike(pattern)
                | ProductCategory.description.ilike(pattern)
            )

    category_rows = db.execute(
        select(
            ProductCategory,
            func.count(Product.id).label("product_count"),
        )
        .outerjoin(Product, Product.category_id == ProductCategory.id)
        .where(*filters)
        .group_by(ProductCategory.id)
        .order_by(ProductCategory.name.asc(), ProductCategory.id.asc())
    ).all()

    return [
        AdminCategoryResponse(
            id=cat.id,
            name=cat.name,
            description=cat.description,
            is_active=cat.is_active,
            product_count=prod_count,
        )
        for cat, prod_count in category_rows
    ]


@router.post(
    "/categories",
    response_model=AdminCategoryResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_category(
    payload: AdminCategoryCreateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminCategoryResponse:
    """
    Create a new product category.
    Returns HTTP 409 Conflict if category name already exists (case-insensitive).
    """
    clean_name = payload.name.strip()
    existing = db.scalar(
        select(ProductCategory.id).where(
            func.lower(ProductCategory.name) == func.lower(clean_name)
        )
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A category with this name already exists",
        )

    category = ProductCategory(
        name=clean_name,
        description=payload.description.strip() if payload.description else None,
        is_active=payload.is_active,
    )

    try:
        db.add(category)
        db.commit()
        db.refresh(category)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A category with this name already exists",
        )

    return AdminCategoryResponse(
        id=category.id,
        name=category.name,
        description=category.description,
        is_active=category.is_active,
        product_count=0,
    )


@router.post("/categories/{category_id}/status", response_model=AdminCategoryResponse)
def update_category_status(
    category_id: int,
    payload: CategoryStatusUpdateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminCategoryResponse:
    """
    Activate or deactivate a category.
    Soft-toggle only; never hard-deletes.
    """
    category = db.get(ProductCategory, category_id)
    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found",
        )

    category.is_active = payload.is_active
    db.commit()
    db.refresh(category)

    product_count = db.scalar(
        select(func.count(Product.id)).where(Product.category_id == category.id)
    ) or 0

    return AdminCategoryResponse(
        id=category.id,
        name=category.name,
        description=category.description,
        is_active=category.is_active,
        product_count=product_count,
    )
