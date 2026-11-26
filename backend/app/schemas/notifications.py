from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class NotificationResponse(BaseModel):
    id: int
    type: str
    title: str
    body: str
    order_id: Optional[int] = None
    order_number: Optional[str] = None
    partner_name: Optional[str] = None
    is_read: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class NotificationsListResponse(BaseModel):
    notifications: list[NotificationResponse]
    unread_count: int
