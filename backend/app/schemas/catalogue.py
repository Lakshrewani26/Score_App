from decimal import Decimal
from typing import Literal

from pydantic import BaseModel


class CategoryResponse(BaseModel):
    id: int
    name: str
    description: str | None


class ProductResponse(BaseModel):
    id: int
    category_id: int
    category_name: str | None
    product_code: str
    name: str
    description: str | None
    package_quantity: str | None = None
    vehicle_type: Literal["2-Wheeler", "3-Wheeler", "Both"]
    price: Decimal | None = None
    image_url: str | None


class ProductPagination(BaseModel):
    total: int
    page: int
    page_size: int
    total_pages: int


class ProductListResponse(BaseModel):
    items: list[ProductResponse]
    pagination: ProductPagination
