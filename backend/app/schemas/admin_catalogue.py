from __future__ import annotations

from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class AdminProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_code: str
    name: str
    category_id: int
    category_name: str | None = None
    category_is_active: bool = True
    vehicle_type: Literal["2-Wheeler", "3-Wheeler", "Both"]
    price: Decimal | None = None
    description: str | None = None
    image_url: str | None = None
    is_active: bool


class AdminProductPagination(BaseModel):
    total: int
    page: int
    page_size: int
    total_pages: int


class AdminProductListResponse(BaseModel):
    items: list[AdminProductResponse]
    pagination: AdminProductPagination
    total: int
    page: int
    page_size: int
    total_pages: int


class AdminProductCreateRequest(BaseModel):
    product_code: str = Field(..., min_length=1, max_length=50)
    name: str = Field(..., min_length=1, max_length=200)
    category_id: int = Field(..., ge=1)
    vehicle_type: Literal["2-Wheeler", "3-Wheeler", "Both"]
    price: Decimal | None = None
    description: str | None = None
    image_url: str | None = Field(default=None, max_length=2048)
    is_active: bool = True

    @field_validator("product_code", "name")
    @classmethod
    def validate_not_blank(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Field cannot be empty or whitespace only")
        return cleaned

    @field_validator("price")
    @classmethod
    def validate_price(cls, v: Decimal | None) -> Decimal | None:
        if v is not None and v < Decimal("0.00"):
            raise ValueError("Price cannot be negative")
        return v


class AdminProductUpdateRequest(BaseModel):
    product_code: str | None = Field(default=None, min_length=1, max_length=50)
    name: str | None = Field(default=None, min_length=1, max_length=200)
    category_id: int | None = Field(default=None, ge=1)
    vehicle_type: Literal["2-Wheeler", "3-Wheeler", "Both"] | None = None
    price: Decimal | None = None
    description: str | None = None
    image_url: str | None = Field(default=None, max_length=2048)
    is_active: bool | None = None

    @field_validator("product_code", "name")
    @classmethod
    def validate_not_blank(cls, v: str | None) -> str | None:
        if v is not None:
            cleaned = v.strip()
            if not cleaned:
                raise ValueError("Field cannot be empty or whitespace only")
            return cleaned
        return v

    @field_validator("price")
    @classmethod
    def validate_price(cls, v: Decimal | None) -> Decimal | None:
        if v is not None and v < Decimal("0.00"):
            raise ValueError("Price cannot be negative")
        return v


class ProductStatusUpdateRequest(BaseModel):
    is_active: bool


class AdminCategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str | None = None
    is_active: bool
    product_count: int = 0


class AdminCategoryCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    description: str | None = None
    is_active: bool = True

    @field_validator("name")
    @classmethod
    def validate_name_not_blank(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Category name cannot be empty or whitespace only")
        return cleaned


class CategoryStatusUpdateRequest(BaseModel):
    is_active: bool
