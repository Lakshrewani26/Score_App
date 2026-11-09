import logging

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.exc import SQLAlchemyError

from app.core.config import settings
from app.db.session import DatabaseNotConfiguredError, check_database_connection
from app.routers.admin import router as admin_router
from app.routers.admin_catalogue import router as admin_catalogue_router
from app.routers.admin_orders import router as admin_orders_router
from app.routers.admin_reports import router as admin_reports_router
from app.routers.admin_qr import router as admin_qr_router
from app.routers.admin_settings import router as admin_settings_router
from app.routers.admin_zones import router as admin_zones_router
from app.routers.auth import router as auth_router
from app.routers.catalogue import router as catalogue_router
from app.routers.customer import router as customer_router
from app.routers.orders import router as orders_router
from app.routers.partner import router as partner_router
from app.routers.qr_scan import router as qr_scan_router
from app.routers.staff import router as staff_router

app = FastAPI(title=settings.app_name)

if settings.environment.lower() == "development":
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Accept", "Content-Type", "Authorization"],
    )
elif settings.cors_allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allowed_origins,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Accept", "Content-Type", "Authorization"],
    )

logger = logging.getLogger(__name__)

app.include_router(auth_router)
app.include_router(customer_router)
app.include_router(admin_router)
app.include_router(catalogue_router)
app.include_router(orders_router)
app.include_router(partner_router)
app.include_router(admin_catalogue_router)
app.include_router(admin_orders_router)
app.include_router(admin_reports_router)
app.include_router(admin_qr_router)
app.include_router(admin_settings_router)
app.include_router(admin_zones_router)
app.include_router(staff_router)
app.include_router(qr_scan_router)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/ready/database")
def database_readiness_check() -> dict[str, str]:
    try:
        check_database_connection()
    except (DatabaseNotConfiguredError, SQLAlchemyError) as exc:
        logger.exception("Database readiness check failed")
        raise HTTPException(
            status_code=503,
            detail="Database is unavailable",
        ) from exc

    return {"status": "ok"}
