# Admin System Settings & Points Rules — Inspection Report (Phase 7)

## 1. Executive Summary

This report documents the architectural inspection of `Score_App` (Backend: FastAPI, PostgreSQL, SQLAlchemy, Alembic; Frontend: Flutter / Dart) to determine supported system settings and outline the implementation for **Admin System Settings** and the **Owner-Controlled Points System Rules** feature.

The baseline test status is verified and green:
- **Backend**: 167/167 tests passing (`pytest backend/tests -v`).
- **Flutter**: 339/339 tests passing (`flutter test`).
- **Static Analysis**: 0 analyzer issues (`flutter analyze`).

---

## 2. Existing Implementation Findings

### Backend Architecture
- **FastAPI Core (`backend/app/main.py`)**:
  - Routers mounted under `/api/v1`: `auth`, `admin` (user management & password updates), `catalogue`, `admin_catalogue`, `admin_orders`, and `admin_reports`.
  - CORS configuration permits origins with methods `["GET", "POST", "OPTIONS"]` in development and configured production origins.
  - Health checks: `GET /health` and `GET /ready/database`.
- **Database & Models (`backend/app/models.py`)**:
  - Existing models: `User`, `CustomerProfile`, `PartnerProfile`, `StaffProfile`, `OtpVerification`, `ProductCategory`, `Product`, `CatalogueImportAudit`, `Order`, `OrderItem`, `OrderStatusHistory`, `StockRequest`, `StockRequestItem`, `StockRequestStatusHistory`, `StaffPartnerAssignment`, `StaffPaymentRecord`, `PaymentStatusHistory`.
  - There is currently **no `settings` table** and **no `points_rules` or points transaction table** in PostgreSQL.
  - Phase 6 reports explicitly declares `"points_balances_and_history"` as an `unsupported_metric`.
- **Configuration & Security (`backend/app/core/config.py`, `backend/app/core/security.py`)**:
  - `Settings` class loads environment-only settings: `app_name`, `environment`, `database_url`, `jwt_secret_key`, `jwt_algorithm`, `jwt_access_token_expire_minutes`, and `cors_allowed_origins`.
  - `require_admin` dependency enforces authentication, active user status (`is_active = True`), and role check (`role == "admin"`).
  - All sensitive credentials (database URL, JWT secret keys, passwords) must remain strictly server-side and never exposed.
- **Alembic Migrations (`backend/migrations/versions/`)**:
  - `56ecec28acb3_initial_schema.py`
  - `d1a1d82f1e16_make_product_price_nullable.py`
  - The migration chain is linear and intact.

### Flutter Architecture
- **Admin Dashboard (`lib/features/admin/home/admin_home_screen.dart`)**:
  - `_buildPlaceholderGrid()` already contains a tile:
    - Title: `'System Settings'`
    - Subtitle: `'Security policies & configurations'`
    - Icon: `Icons.settings_suggest_rounded`
    - Color: `Color(0xFF5E35B1)`
    - Currently displays a SnackBar: `'System Settings module is coming soon'`.
- **API Services & Session Management (`lib/core/services/`)**:
  - `AdminApi` delegates sub-modules via getters: `catalogue` (`AdminCatalogueApi`), `orders` (`AdminOrdersApi`), and `reports` (`AdminReportsApi`).
  - `AdminSessionManager` provides centralized token and current user caching with automatic Authorization header injection.
  - `AdminApiException` provides consistent client-side error normalization.
- **Admin UI Conventions**:
  - High-contrast card designs with white backgrounds, `Color(0xFFCBEBFF)` borders, subtle shadows, and royal blue / deep blue branding (`Color(0xFF072763)`, `Color(0xFF083FA5)`).
  - Explicit dialogs with form validation, confirmation before critical state changes, and defensive state management.

---

## 3. Candidate Settings & Their Source of Truth

| Setting Category | Candidate Field / Configuration | Existing Source of Truth | Safe to Manage via UI? | Action in Phase 7 |
| :--- | :--- | :--- | :--- | :--- |
| **System Info** | App name, environment, release phase, database health | `app.core.config.settings`, DB engine check | Yes (Read-only) | Expose read-only via API & UI |
| **Secrets / Deployment** | `DATABASE_URL`, `JWT_SECRET_KEY`, token expiration | `backend/.env` / environment variables | **NO** (High Risk) | Exclude strictly; never return or accept edits |
| **Catalogue Settings** | Visibility rules, category active status | `Product.is_active`, `ProductCategory.is_active` | Yes | Already managed in Catalogue Management module |
| **Order Settings** | Status progression, approval thresholds | Hardcoded business rules in `admin_orders.py` | No (Requires owner policy) | Do not invent or alter existing workflow |
| **QR Code Policies** | QR batch sizes, token allocation rules | None / upcoming phase | No (Deferred) | Preserve standalone notice tile; no activation |
| **Points System Rules** | Owner-defined points earning, redemption, and transfer rules | New table `points_rules` in PostgreSQL | **YES (Owner/Admin required)** | Implement persistent database model, API, and UI |

---

## 4. Settings Safe to Implement Now

1. **Read-Only System Information**:
   - `app_name`: from `settings.app_name` ("Score API").
   - `environment`: from `settings.environment` ("development" / "production").
   - `api_version`: release version string (e.g., "1.0.0 (Phase 7)").
   - `database_status`: live connectivity status ("connected" / "degraded").
   - Strictly read-only; zero persistent schema changes required for this section.

2. **Owner-Controlled Points System Rules**:
   - Persisted in a dedicated `points_rules` PostgreSQL table.
   - Admin/Owner can create, list, edit, and toggle active status of rules directly in the app.
   - Structured, validated fields:
     - `rule_name`: Human-readable name.
     - `rule_description`: Multiline explanatory description (stored as plain text; **never executed as code, SQL, or expressions**).
     - `category`: Validated rule type (`product_qr_scan`, `invoice_qr_scan`, `redemption`, `customer_to_partner_transfer`, `partner_to_staff_transfer`).
     - `points_awarded`: Non-negative integer (points given on earning events).
     - `points_required`: Non-negative integer (points deducted for redemption).
     - `min_transaction_value`: Optional non-negative decimal threshold.
     - `max_transaction_value`: Optional non-negative decimal threshold.
     - `effective_from`: Optional timezone-aware datetime.
     - `effective_to`: Optional timezone-aware datetime.
     - `is_active`: Boolean status flag (defaults to `True`).
     - Audit tracking: `created_by` and `updated_by` referencing `users.id`, with `created_at` and `updated_at`.

---

## 5. Settings Requiring Owner Approval

1. **Direct Execution / Ledger Integration of Points**:
   - There is currently no points wallet, balance ledger, or QR-scanning execution engine in the database.
   - Connecting rules to auto-deduct or auto-credit points requires an owner decision on ledger transaction schemas and event hooks. In Phase 7, rules are persistently managed and queried, with execution integration documented for subsequent phases.
2. **Order Approval Bypasses / Custom Timeouts**:
   - Workflow transitions are currently fixed by specification. Dynamic timeouts or automatic approvals require business owner approval.
3. **QR Code Batch Allocation & Export**:
   - Remained deferred as per project specifications.

---

## 6. Proposed API Contracts

### Endpoints
All endpoints are scoped under `/api/v1/admin` and require active Admin authorization (`require_admin`).

#### A. System Information
- **`GET /api/v1/admin/settings/system-info`**
  - **Response 200**:
    ```json
    {
      "app_name": "Score API",
      "environment": "development",
      "api_version": "1.0.0 (Phase 7)",
      "database_status": "connected"
    }
    ```

#### B. Points System Rules
- **`GET /api/v1/admin/points-rules`**
  - **Query Params**: `category` (optional), `is_active` (optional), `search` (optional)
  - **Response 200**:
    ```json
    {
      "items": [
        {
          "id": 1,
          "rule_name": "Standard Customer Scan",
          "rule_description": "Award 50 points when a customer scans an authentic product QR code.",
          "category": "product_qr_scan",
          "points_awarded": 50,
          "points_required": null,
          "min_transaction_value": null,
          "max_transaction_value": null,
          "effective_from": null,
          "effective_to": null,
          "is_active": true,
          "created_at": "2026-10-26T06:40:00Z",
          "updated_at": "2026-10-26T06:40:00Z",
          "created_by": 1,
          "updated_by": 1
        }
      ],
      "total": 1
    }
    ```
- **`POST /api/v1/admin/points-rules`**
  - **Payload**:
    ```json
    {
      "rule_name": "Mechanic Tier 1 Bonus",
      "rule_description": "100 points awarded for qualifying invoice scans above 1000 INR",
      "category": "invoice_qr_scan",
      "points_awarded": 100,
      "points_required": null,
      "min_transaction_value": 1000.0,
      "max_transaction_value": null,
      "effective_from": null,
      "effective_to": null,
      "is_active": true
    }
    ```
  - **Response 201**: Returns created rule object.
- **`GET /api/v1/admin/points-rules/{rule_id}`**
  - **Response 200**: Returns rule detail object or 404 if not found.
- **`PATCH /api/v1/admin/points-rules/{rule_id}`** (and `POST /api/v1/admin/points-rules/{rule_id}/update` for HTTP fallback)
  - **Payload**: Partial update of editable fields.
  - **Response 200**: Returns updated rule object.
- **`POST /api/v1/admin/points-rules/{rule_id}/status`** (and `PATCH /api/v1/admin/points-rules/{rule_id}/status`)
  - **Payload**: `{"is_active": false}`
  - **Response 200**: Returns updated rule object.

---

## 7. Proposed Frontend Design

### Admin System Settings Screen (`AdminSettingsScreen`)
- **Navigation**:
  - Connect the existing `'System Settings'` tile in `AdminHomeScreen` to push `AdminSettingsScreen`.
  - App bar with back arrow returning to dashboard.
- **Sections**:
  1. **System Information Card**:
     - Visual badges for Environment (`development` / `production`), API Version (`Phase 7`), and Database Status (`Connected`).
     - Transparent notice indicating secrets and credentials are secure and deployment-managed.
  2. **Owner-Controlled Points System Rules Section**:
     - Section header with clear explanation and **"Create Rule"** action button.
     - Category filter chips: `All`, `Product QR Scan`, `Invoice QR Scan`, `Redemption`, `Customer -> Partner`, `Partner -> Staff`.
     - Active / Inactive status filter switch or chips.
     - Rule cards showing:
       - Rule name and active/inactive badge.
       - Category label with dedicated color scheme and icon.
       - Points awarded / required badge.
       - Transaction eligibility criteria (min/max transaction value) if defined.
       - Effective dates if configured.
       - Human-readable description.
       - Quick action buttons: **Edit Rule** and **Activate / Deactivate**.
  3. **Create / Edit Rule Dialog (`AdminPointsRuleFormDialog`)**:
     - Modal form with real-time validation:
       - Name (required, non-empty).
       - Category (dropdown selection).
       - Description (multiline text area).
       - Points Awarded (numeric input, >= 0).
       - Points Required (numeric input, >= 0).
       - Min / Max Transaction Values (decimal inputs, validated min <= max).
       - Effective Date Range (date picker, validated start <= end).
       - Active status toggle.
     - Submission spinner and error banner; prevents double-tap submissions.
  4. **Confirmation Dialog**:
     - For toggling active/inactive status. Rules are never permanently deleted, preserving audit history.

---

## 8. Migration Requirements

- **New Migration**: `backend/migrations/versions/<hash>_create_points_rules_table.py`
  - Depends on `d1a1d82f1e16`.
  - Table name: `points_rules`.
  - Columns:
    - `id` (Integer, Primary Key)
    - `rule_name` (String(120), nullable=False)
    - `rule_description` (Text, nullable=True)
    - `category` (String(50), nullable=False)
    - `points_awarded` (Integer, nullable=True)
    - `points_required` (Integer, nullable=True)
    - `min_transaction_value` (Numeric(12, 2), nullable=True)
    - `max_transaction_value` (Numeric(12, 2), nullable=True)
    - `effective_from` (DateTime(timezone=True), nullable=True)
    - `effective_to` (DateTime(timezone=True), nullable=True)
    - `is_active` (Boolean, nullable=False, server_default=true())
    - `created_at` (DateTime(timezone=True), nullable=False, server_default=func.now())
    - `updated_at` (DateTime(timezone=True), nullable=False, server_default=func.now())
    - `created_by` (ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    - `updated_by` (ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
  - Table Constraints:
    - `CheckConstraint("category IN ('product_qr_scan', 'invoice_qr_scan', 'redemption', 'customer_to_partner_transfer', 'partner_to_staff_transfer')", name="supported_rule_category")`
    - `CheckConstraint("points_awarded IS NULL OR points_awarded >= 0", name="nonnegative_points_awarded")`
    - `CheckConstraint("points_required IS NULL OR points_required >= 0", name="nonnegative_points_required")`
    - `CheckConstraint("min_transaction_value IS NULL OR min_transaction_value >= 0", name="nonnegative_min_transaction_value")`
    - `CheckConstraint("max_transaction_value IS NULL OR max_transaction_value >= 0", name="nonnegative_max_transaction_value")`
  - Indexes:
    - `ix_points_rules_category`
    - `ix_points_rules_is_active`
- **Reversibility**:
  - `downgrade()` cleanly drops the table and associated indexes.
  - Zero modification to existing tables (`products`, `orders`, `users`).

---

## 9. Risks & Dependencies

1. **No Live Points Ledger**:
   - Points rules are configured and persisted in Phase 7. The actual ledger and wallet balances will consume these rules once the points ledger is developed.
2. **CORS Method Support**:
   - In `main.py`, CORS middleware currently specifies `allow_methods=["GET", "POST", "OPTIONS"]`. Both `PATCH` and `POST` endpoints should be supported (or `PATCH` explicitly added to CORS allowed methods) to ensure compatibility across all deployment environments.
3. **Data Integrity & Non-Deletion**:
   - Rules must not be hard deleted so any future transaction log referencing `rule_id` maintains referential integrity. Deactivation is the only supported archival method.
4. **Credential Security**:
   - No `.env` secrets or backend connection strings may be reflected by the System Settings endpoints.
