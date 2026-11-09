from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from pydantic import BaseModel, ConfigDict, Field, model_validator


class PartnerTransferRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    token: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Raw QR code token or scanned QR URL payload.",
    )
    code_data: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Scanned QR code URL or raw token payload.",
    )
    amount: int = Field(
        ...,
        description="Number of loyalty points to transfer (must be a positive integer).",
    )
    idempotency_key: str = Field(
        ...,
        min_length=1,
        max_length=128,
        description="Client-provided unique key for idempotency and duplicate request protection.",
    )

    @model_validator(mode="before")
    @classmethod
    def validate_request(cls, data: Any) -> Any:
        if isinstance(data, dict):
            raw = data.get("token") or data.get("code_data")
            if not raw or not str(raw).strip():
                raise ValueError("Either 'token' or 'code_data' must be provided and non-empty.")
            if not data.get("token"):
                data["token"] = str(raw).strip()
            key = data.get("idempotency_key")
            if key is not None:
                cleaned_key = str(key).strip()
                if not cleaned_key:
                    raise ValueError("'idempotency_key' must not be blank.")
                data["idempotency_key"] = cleaned_key
        return data


class PartnerTransferResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    transfer_id: int
    amount: int
    sender_id: int
    recipient_id: int
    recipient_name: Optional[str] = None
    recipient_staff_id: Optional[str] = None
    created_at: datetime
    sender_balance: int
    recipient_balance: int
    is_idempotent_replay: bool = False
