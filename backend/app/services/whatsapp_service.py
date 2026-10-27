from __future__ import annotations

import logging
import re
from typing import TYPE_CHECKING, Optional

import httpx

from app.core.config import settings
from app.schemas.orders import WhatsAppDeliveryResult

if TYPE_CHECKING:
    from app.models import Order

logger = logging.getLogger(__name__)


def normalize_phone_number(raw_phone: str | None) -> str | None:
    """
    Cleans and normalizes phone number to E.164 digits format without spaces or symbols.
    Defaults to adding India country code (+91) if 10 digits are supplied.
    """
    if not raw_phone:
        return None
    cleaned = re.sub(r"[^\d+]", "", raw_phone.strip())
    if not cleaned:
        return None

    # Strip leading + for WhatsApp Cloud API 'to' parameter
    digits = cleaned.lstrip("+")
    if len(digits) == 10 and not digits.startswith("91"):
        digits = f"91{digits}"
    return digits


class WhatsAppService:
    """
    Service responsible for dispatching order PDF documents via WhatsApp Business Cloud API.
    Handles credential validation, media upload, message dispatch, and structured reporting.
    """

    def __init__(
        self,
        api_token: str | None = None,
        phone_number_id: str | None = None,
        provider: str | None = None,
        http_client: httpx.Client | None = None,
    ):
        self.api_token = (api_token or settings.whatsapp_api_token or "").strip()
        self.phone_number_id = (phone_number_id or settings.whatsapp_phone_number_id or "").strip()
        self.provider = (provider or settings.whatsapp_provider or "cloud_api").strip()
        self._http_client = http_client

    def is_configured(self) -> bool:
        """Check if WhatsApp Cloud API has minimal credentials configured."""
        return bool(self.api_token and self.phone_number_id)

    def send_order_pdf(
        self,
        order: Order,
        pdf_bytes: bytes,
        recipient_override: str | None = None,
    ) -> WhatsAppDeliveryResult:
        """
        Sends the order PDF to the partner's registered mobile number or configured admin recipient.
        Never fabricates delivery success; reports exact status and errors.
        """
        partner_mobile = recipient_override or (order.partner.mobile if order.partner else None)
        recipient = normalize_phone_number(partner_mobile)

        if not recipient:
            return WhatsAppDeliveryResult(
                success=False,
                status="invalid_recipient",
                message="Partner does not have a valid mobile number for WhatsApp delivery.",
                recipient=None,
                provider=self.provider,
                message_id=None,
            )

        if not self.is_configured():
            logger.info(
                "WhatsApp Cloud API is not configured with credentials. "
                "Order #%s saved, but live WhatsApp delivery skipped.",
                order.order_number,
            )
            return WhatsAppDeliveryResult(
                success=False,
                status="missing_credentials",
                message=(
                    "WhatsApp provider is not configured. Set WHATSAPP_API_TOKEN and "
                    "WHATSAPP_PHONE_NUMBER_ID in environment to enable live delivery."
                ),
                recipient=f"+{recipient}",
                provider=self.provider,
                message_id=None,
            )

        # Execute WhatsApp Business Cloud API delivery
        filename = f"Score_Order_{order.order_number}.pdf"
        caption = (
            f"Score Order #{order.order_number} has been placed successfully.\n"
            f"Current Status: {order.status.replace('_', ' ').title()}.\n"
            "This order is subject to Staff / Admin approval."
        )

        client = self._http_client or httpx.Client(timeout=20.0)
        close_client = self._http_client is None

        try:
            # 1. Upload media binary to Meta WhatsApp Media Endpoint
            media_upload_url = f"https://graph.facebook.com/v18.0/{self.phone_number_id}/media"
            headers = {
                "Authorization": f"Bearer {self.api_token}",
            }
            files = {
                "file": (filename, pdf_bytes, "application/pdf"),
            }
            data = {
                "messaging_product": "whatsapp",
                "type": "application/pdf",
            }

            upload_resp = client.post(media_upload_url, headers=headers, data=data, files=files)

            if upload_resp.status_code not in (200, 201):
                err_detail = "Failed to upload document to WhatsApp media service."
                try:
                    err_json = upload_resp.json()
                    err_detail = err_json.get("error", {}).get("message", err_detail)
                except Exception:
                    pass
                logger.warning("WhatsApp media upload failed: %s (HTTP %d)", err_detail, upload_resp.status_code)
                return WhatsAppDeliveryResult(
                    success=False,
                    status="provider_upload_failed",
                    message=f"WhatsApp upload failed: {err_detail}",
                    recipient=f"+{recipient}",
                    provider=self.provider,
                    message_id=None,
                )

            media_id = upload_resp.json().get("id")
            if not media_id:
                return WhatsAppDeliveryResult(
                    success=False,
                    status="provider_upload_failed",
                    message="WhatsApp media service did not return an attachment ID.",
                    recipient=f"+{recipient}",
                    provider=self.provider,
                    message_id=None,
                )

            # 2. Send Document Message using the uploaded media ID
            messages_url = f"https://graph.facebook.com/v18.0/{self.phone_number_id}/messages"
            msg_payload = {
                "messaging_product": "whatsapp",
                "recipient_type": "individual",
                "to": recipient,
                "type": "document",
                "document": {
                    "id": media_id,
                    "caption": caption,
                    "filename": filename,
                },
            }

            send_resp = client.post(messages_url, headers=headers, json=msg_payload)

            if send_resp.status_code in (200, 201):
                send_data = send_resp.json()
                msg_ids = send_data.get("messages", [])
                message_id = msg_ids[0].get("id") if msg_ids else None
                return WhatsAppDeliveryResult(
                    success=True,
                    status="delivered",
                    message=f"PDF sent via WhatsApp Cloud API to +{recipient}",
                    recipient=f"+{recipient}",
                    provider=self.provider,
                    message_id=message_id,
                )
            else:
                err_detail = "WhatsApp message sending failed."
                try:
                    err_json = send_resp.json()
                    err_detail = err_json.get("error", {}).get("message", err_detail)
                except Exception:
                    pass
                logger.warning("WhatsApp message dispatch failed: %s (HTTP %d)", err_detail, send_resp.status_code)
                return WhatsAppDeliveryResult(
                    success=False,
                    status="provider_dispatch_failed",
                    message=f"WhatsApp dispatch failed: {err_detail}",
                    recipient=f"+{recipient}",
                    provider=self.provider,
                    message_id=None,
                )

        except (httpx.ConnectError, httpx.TimeoutException) as exc:
            logger.warning("WhatsApp API network timeout or connection error: %s", str(exc))
            return WhatsAppDeliveryResult(
                success=False,
                status="network_timeout",
                message=f"Network error communicating with WhatsApp API: {str(exc)}",
                recipient=f"+{recipient}",
                provider=self.provider,
                message_id=None,
            )
        except Exception as exc:
            logger.exception("Unexpected error in WhatsApp PDF delivery: %s", str(exc))
            return WhatsAppDeliveryResult(
                success=False,
                status="unexpected_error",
                message=f"Failed to send WhatsApp message: {str(exc)}",
                recipient=f"+{recipient}",
                provider=self.provider,
                message_id=None,
            )
        finally:
            if close_client:
                client.close()


# Default singleton instance
whatsapp_service = WhatsAppService()
