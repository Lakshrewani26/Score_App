# Phase 8 — Admin QR Code Generation & Excel Export: Final Implementation Report

**Project:** `Score_App`  
**Feature:** Phase 8 — Admin QR Code Generation & Excel (.xlsx) Batch Export  
**Status:** Complete  
**Date:** 2026-10-26  
**Operating System:** Windows  
**Shell:** PowerShell  

---

## 1. Executive Summary & Requirements

In response to the feature requirement to implement Admin QR Code Generation and **export generated QR numbers/tokens through formatted Excel files**, this phase delivers:

1. **Persistent QR Batch & Code Data Models:**
   - Database tables `qr_batches` and `qr_codes` to track allocated token sets, points rules, and target products/dealers.
   - Cryptographically random unique 32-character hex tokens generated server-side.
2. **Microsoft Excel (.xlsx) Batch Export Engine:**
   - Implemented with `openpyxl` producing styled spreadsheets with Score-themed header blocks, auto-fitted columns, borders, and complete metadata.
   - Accessible via `GET /api/v1/admin/qr/batches/{id}/export/excel` returning `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`.
   - Secondary CSV export maintained at `GET /api/v1/admin/qr/batches/{id}/export/csv`.
3. **Flutter Admin UI & Visual QR Rendering:**
   - Responsive category selectors for **Product QR**, **Invoice QR**, **Partner QR**, and **Staff QR**.
   - Interactive batch creation dialog with product picker, points reward rule linking, and quantity selection.
   - Recent batches listing with one-tap **Export Excel** action button, active count badges, and a **View Codes** dialog that renders visual QR codes using `qr_flutter`.

---

## 2. Database Schema & Alembic Migration

### 2.1 Schema Tables

#### Table: `qr_batches`
- `id`: Integer primary key.
- `batch_number`: String(60) unique, indexed (format: `BATCH-YYYYMMDD-XXXXXX`).
- `qr_type`: String(50) non-nullable (`product`, `invoice`, `staff`, `partner`).
- `description`: Text nullable.
- `points_rule_id`: Integer foreign key $\rightarrow$ `points_rules.id` (`ondelete="SET NULL"`).
- `product_id`: Integer foreign key $\rightarrow$ `products.id` (`ondelete="SET NULL"`).
- `target_user_id`: Integer foreign key $\rightarrow$ `users.id` (`ondelete="SET NULL"`).
- `quantity`: Integer non-nullable (check constraint `1 <= quantity <= 1000`).
- `status`: String(20) default `'completed'` (`active`, `completed`, `cancelled`).
- `metadata_json`: Text nullable.
- `created_by`: Integer foreign key $\rightarrow$ `users.id`.
- `created_at`: DateTime(timezone=True) default `now()`.

#### Table: `qr_codes`
- `id`: Integer primary key.
- `batch_id`: Integer foreign key $\rightarrow$ `qr_batches.id` (`ondelete="CASCADE"`).
- `qr_type`: String(50) non-nullable (`product`, `invoice`, `staff`, `partner`).
- `token`: String(64) unique, indexed (32-character uppercase hex string).
- `code_data`: Text non-nullable (URL payload: `score://qr/v1?token={token}&type={type}`).
- `points_awarded`: Integer nullable (inherited from linked `PointsRule`).
- `product_id`: Integer foreign key $\rightarrow$ `products.id`.
- `target_user_id`: Integer foreign key $\rightarrow$ `users.id`.
- `status`: String(20) default `'active'` (`active`, `redeemed`, `voided`, `expired`).
- `redeemed_by`: Integer foreign key $\rightarrow$ `users.id` nullable.
- `redeemed_at`: DateTime(timezone=True) nullable.
- `expires_at`: DateTime(timezone=True) nullable.
- `created_at`: DateTime(timezone=True) default `now()`.

### 2.2 Alembic Migration
- **File:** `backend/migrations/versions/b2c3d4e5f6a7_create_qr_batches_and_codes_tables.py`
- **Revision ID:** `b2c3d4e5f6a7`
- **Revises:** `e7b2c9d4f1a3` (Phase 7 points rules schema)
- **Tables created:** `qr_batches`, `qr_codes` with all check constraints, foreign keys, and indexes.

---

## 3. Backend Implementation & Excel Export Architecture

### 3.1 Excel Export Engine (`backend/app/routers/admin_qr.py`)
Endpoint: `GET /api/v1/admin/qr/batches/{batch_id}/export/excel`
- Generates a workbook using `openpyxl.Workbook()`.
- Applies Score deep blue fill (`#002766`), white bold text, centered alignment, and light grey cell grid borders.
- Calculates column dimensions dynamically based on content length.
- Exports the following columns:
  1. `S.No` — Row counter
  2. `Batch Number` — Unique identifier (e.g. `BATCH-20261026-A1B2`)
  3. `QR Token` — 32-character cryptographically secure token
  4. `QR Code Data (Payload)` — Encoded URL string for scanner consumption
  5. `Category` — `PRODUCT`, `INVOICE`, `PARTNER`, `STAFF`
  6. `Points Awarded` — Points configured or awarded on scan
  7. `Target Item / User` — Product Name & SKU or Dealer/Staff Name & Role
  8. `Status` — `ACTIVE`, `REDEEMED`, `VOIDED`, `EXPIRED`
  9. `Created Date (UTC)` — Formatted timestamp (`YYYY-MM-DD HH:MM:SS`)
  10. `Expiry Date` — Expiration timestamp or `'Never'`
- Delivered via `StreamingResponse` with `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` and `Content-Disposition: attachment; filename="{batch_number}_qr_codes.xlsx"`.

### 3.2 Endpoints Summary
| Endpoint | Method | Role | Description |
|---|---|---|---|
| `/api/v1/admin/qr/batches` | `POST` | Admin | Creates batch, generates unique QR tokens, and binds points rules. |
| `/api/v1/admin/qr/batches` | `GET` | Admin | Lists batches with pagination, type, and search filters. |
| `/api/v1/admin/qr/batches/{id}` | `GET` | Admin | Returns batch details and counts. |
| `/api/v1/admin/qr/batches/{id}/codes` | `GET` | Admin | Lists individual QR codes inside a batch. |
| `/api/v1/admin/qr/batches/{id}/export/excel` | `GET` | Admin | **Streams styled Excel (.xlsx) file download.** |
| `/api/v1/admin/qr/batches/{id}/export/csv` | `GET` | Admin | Streams CSV file download. |
| `/api/v1/admin/qr/codes/{id}/status` | `PATCH` / `POST` | Admin | Toggles code status (`active` $\leftrightarrow$ `voided`). |

---

## 4. Flutter UI & Excel Export Integration

### 4.1 Data Models & API Service
- **Models:** [`AdminQrBatch`](file:///c:/Users/Harshita/OneDrive/Desktop/Score_App/lib/core/models/admin_qr_models.dart), [`AdminQrCode`](file:///c:/Users/Harshita/OneDrive/Desktop/Score_App/lib/core/models/admin_qr_models.dart), [`AdminQrBatchPayload`](file:///c:/Users/Harshita/OneDrive/Desktop/Score_App/lib/core/models/admin_qr_models.dart).
- **Service:** [`AdminQrApi`](file:///c:/Users/Harshita/OneDrive/Desktop/Score_App/lib/core/services/admin_qr_api.dart) provides:
  - `createBatch()`, `getBatches()`, `getBatch()`, `getBatchCodes()`.
  - `downloadBatchExcel()` — Fetches `.xlsx` raw bytes (`Uint8List`).
  - `downloadBatchCsv()` — Fetches `.csv` string.
  - `updateCodeStatus()` — Voids or activates a token.
- **Delegation:** Exposed via `adminApi.qr` on `AdminApi`.

### 4.2 Screens & Widgets
1. **[`AdminQrGenerationScreen`](file:///c:/Users/Harshita/OneDrive/Desktop/Score_App/lib/features/admin/qr/admin_qr_generation_screen.dart):**
   - 4 category cards: Product QR, Invoice QR, Staff QR, Partner QR.
   - Tapping any card opens `AdminCreateQrBatchDialog`.
   - "Recent QR Batches" section with search and filter tabs.
   - Each batch card features an **Export Excel** button and a **View Codes** button.
   - Shows active count badge (e.g. `25/25 ACTIVE`).
2. **[`AdminCreateQrBatchDialog`](file:///c:/Users/Harshita/OneDrive/Desktop/Score_App/lib/features/admin/qr/widgets/admin_create_qr_batch_dialog.dart):**
   - Real-time form validation (quantity 1–500).
   - Product dropdown automatically populated from catalogue.
   - Points rule dropdown bound to active `PointsRule`s.
   - Description / batch notes.
3. **[`AdminViewQrCodesDialog`](file:///c:/Users/Harshita/OneDrive/Desktop/Score_App/lib/features/admin/qr/widgets/admin_view_qr_codes_dialog.dart):**
   - Token search field.
   - Direct top-bar **Export to Excel (.xlsx)** button.
   - Visual QR code display using `QrImageView` (`package:qr_flutter`).
   - Token string, points awarded chip, status chip, and void/reactivate toggle button.

---

## 5. Automated Verification & Test Results

### 5.1 Backend Pytest
- **`backend/tests/test_admin_qr.py`:**
  - `test_admin_qr_requires_admin_authorization` $\rightarrow$ PASSED
  - `test_create_product_qr_batch_success` $\rightarrow$ PASSED
  - `test_create_batch_validation_rules` $\rightarrow$ PASSED
  - `test_create_invoice_partner_staff_batches` $\rightarrow$ PASSED
  - `test_export_batch_excel_success` (verifies workbook, sheet title, headers, column values via `openpyxl`) $\rightarrow$ PASSED
  - `test_export_batch_csv_success` $\rightarrow$ PASSED
  - `test_update_qr_code_status` $\rightarrow$ PASSED
  - `test_list_batches_filters_and_search` $\rightarrow$ PASSED
  - `test_get_qr_batch_detail_and_not_found` $\rightarrow$ PASSED
  - **Result: 9 passed in 4.96s**
- **Full Backend Regression Suite:**
  - `pytest backend/tests -q` $\rightarrow$ **187 passed, 0 failed in 100.60s (100%)**

### 5.2 Flutter Test Suite
- **`test/admin_qr_api_test.dart`:**
  - Models serialization, batch creation, code list, **Excel file byte download**, CSV download, and status update $\rightarrow$ **10/10 passed**
- **`test/admin_qr_screen_test.dart`:**
  - Screen rendering, category cards, creation modal, **Excel export button & SnackBar feedback**, view codes dialog $\rightarrow$ **4/4 passed**
- **`test/admin_dashboard_profile_qr_test.dart`:**
  - Navigation, dashboard button, back button, category dialog opening $\rightarrow$ **9/9 passed**
- **Full Flutter Regression Suite:**
  - `flutter test` $\rightarrow$ **372 passed, 0 failed in 1:48 (100%)**
- **Static Code Analysis:**
  - `flutter analyze` $\rightarrow$ **No issues found!**

---

## 6. Files Created and Modified

### Created Files
1. `backend/migrations/versions/b2c3d4e5f6a7_create_qr_batches_and_codes_tables.py`
2. `backend/app/schemas/admin_qr.py`
3. `backend/app/routers/admin_qr.py`
4. `backend/tests/test_admin_qr.py`
5. `lib/core/models/admin_qr_models.dart`
6. `lib/core/services/admin_qr_api.dart`
7. `lib/features/admin/qr/widgets/admin_create_qr_batch_dialog.dart`
8. `lib/features/admin/qr/widgets/admin_view_qr_codes_dialog.dart`
9. `test/admin_qr_api_test.dart`
10. `test/admin_qr_screen_test.dart`
11. `backend/admin_qr_generation_final_report.md`

### Modified Files
1. `backend/app/models.py` (added `QrBatch` and `QrCode` models)
2. `backend/app/main.py` (mounted `admin_qr_router`)
3. `backend/tests/test_models.py` (updated expected tables & revisions count)
4. `lib/core/services/admin_api.dart` (added `qr` API getter delegation)
5. `lib/features/admin/qr/admin_qr_generation_screen.dart` (implemented batch creation, listing, and Excel export)
6. `lib/features/admin/home/admin_home_screen.dart` (passed API instances to QR screen)
7. `test/admin_dashboard_profile_qr_test.dart` (updated category opening assertions)
