# Score API Backend

FastAPI backend for the Score application, with PostgreSQL connectivity through SQLAlchemy 2.x and psycopg 3, with schema management through Alembic.

## Windows PowerShell

Run these commands from the `backend` directory. If `.venv` already exists, activate it and keep using that environment:

```powershell
cd C:\Users\Harshita\OneDrive\Desktop\Score_App\backend
if (-not (Test-Path .venv)) { python -m venv .venv }
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
```

Edit `.env` locally and replace `<username>` and `<password>` in `DATABASE_URL` with the PostgreSQL credentials configured on this computer. Do not commit `.env`. If a credential contains URL-reserved characters, percent-encode it in the URL.

### Create the database

Use the PostgreSQL username configured during installation; do not assume it is `postgres`. The commands prompt for the username, and `psql`/`createdb` can prompt locally for the password. `createdb` creates the database only when the existence check reports that it is absent:

```powershell
$pgUser = Read-Host "PostgreSQL username"
$databaseExists = psql -U $pgUser -h localhost -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'score_app_db'"
if ($LASTEXITCODE -ne 0) { throw "Could not check PostgreSQL databases. Verify the username, server, and local authentication." }
if ($databaseExists.Trim() -ne "1") {
    createdb -U $pgUser -h localhost score_app_db
    if ($LASTEXITCODE -ne 0) { throw "Could not create score_app_db." }
}
```

If PostgreSQL command-line tools are not on `PATH`, run the equivalent commands from the PostgreSQL SQL Shell (`psql`) or create `score_app_db` in pgAdmin. Do not drop or reset an existing database.

### Migrations

The initial schema consists of:

- Identity and profiles: `users`, `customer_profiles`, `partner_profiles`, `staff_profiles`
- OTP verification: `otp_verifications` (stores hashes only)
- Catalogue: `product_categories`, `products`
- Orders and audit history: `orders`, `order_items`, `order_status_history`
- Stock requests and audit history: `stock_requests`, `stock_request_items`, `stock_request_status_history`
- Staff operations: `staff_partner_assignments`, `staff_payment_records`, `payment_status_history`

Order status values are `pending_approval`, `approved_processing`, `dispatched`, `delivered`, and `rejected`. Stock-request values are `pending_approval`, `approved`, and `rejected`. Manually recorded payment statuses are `recorded` and `voided`. Product vehicle types are `2-Wheeler`, `3-Wheeler`, and `Both`. Order item unit prices are snapshots and use fixed-precision numeric columns.

The migration environment loads all models into the shared `Base.metadata` and reads the database URL from application settings; credentials are not stored in `alembic.ini`. Run the commands from this directory. Before creating or applying a migration, confirm the configured database and inspect the existing revision and schema state:

```powershell
python -m alembic current
python -m alembic heads
python -m alembic history
```

Create a revision, inspect the generated file under `migrations\versions`, then apply it:

```powershell
python -m alembic revision --autogenerate -m "describe schema change"
python -m alembic upgrade head
```

For this initial schema, verify the current revision and table list without changing data:

```powershell
python -m alembic current
$pgUser = Read-Host "PostgreSQL username"
psql -U $pgUser -h localhost -d score_app_db -c "SELECT current_database();"
psql -U $pgUser -h localhost -d score_app_db -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
```

Do not drop or reset the database to resolve migration conflicts. Stop and investigate unexpected existing objects instead.

Login/registration endpoints, OTP delivery, QR and redemption flows, points/wallet/transaction features, inventory deduction, actual payment processing or transfers, and Admin UI are deliberately deferred.

### Product catalogue API

The read-only catalogue endpoints are currently public because authentication endpoints have not yet been implemented. Customers and partners can browse the same active catalogue; catalogue endpoints do not create orders.

- `GET /api/v1/categories` returns an array of active categories (`id`, `name`, `description`), ordered by name and then ID.
- `GET /api/v1/products` returns active products in a paginated envelope:

  ```json
  {
    "items": [
      {
        "id": 1,
        "category_id": 1,
        "category_name": "Example category",
        "product_code": "PART-001",
        "name": "Example product",
        "description": null,
        "package_quantity": "10 PC",
        "vehicle_type": "2-Wheeler",
        "price": "125.50",
        "image_url": null
      }
    ],
    "pagination": {
      "total": 1,
      "page": 1,
      "page_size": 20,
      "total_pages": 1
    }
  }
  ```

  Optional filters are `category_id`, `vehicle_type` (`2-Wheeler`, `3-Wheeler`, or `Both`), and `search` (product name, code, or description). `page` defaults to 1; `page_size` defaults to 20 and is limited to 100. Products are ordered by ID. Invalid parameter values return HTTP 422.
- `GET /api/v1/products/{product_id}` returns one active product using the same product fields, or HTTP 404 if it is missing or inactive.

Prices use fixed-precision `NUMERIC(12,2)` values and are serialized as decimal strings to preserve precision. These endpoints expose only catalogue fields.
`package_quantity` is a nullable string containing the source package text when available (for example, `"10 PC"`).

### Tests and API

Run the backend tests:

```powershell
python -m pytest -q
```

`GET /health` remains a process-level health check and does not check PostgreSQL. `GET /ready/database` executes `SELECT 1` against the configured database and returns `503` if `DATABASE_URL` is missing or the connection fails.

To start the API:

```powershell
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Binding to `0.0.0.0` makes the development server reachable from other devices on the LAN; it does not configure Windows Firewall or router isolation. Allow inbound TCP port 8000 on the private network only when needed, and confirm the PC and phone are on the same reachable network. Do not expose the development server to untrusted networks.

Open the interactive API documentation at <http://127.0.0.1:8000/docs>. Health endpoints remain at <http://127.0.0.1:8000/health> and <http://127.0.0.1:8000/ready/database>; catalogue endpoints are under `/api/v1`.

### Flutter Android development

The app uses `http://10.0.2.2:8000` by default on Android, which is for the Android Emulator. For a physical phone, find the development PC's current LAN IPv4 address (for example with `ipconfig`) and pass that actual address as a build-time override; do not use `localhost`, `127.0.0.1`, or a guessed address:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://<PC_LAN_IP>:8000
```

Replace `<PC_LAN_IP>` with the address reachable from the phone, such as `192.168.1.25`. Flutter Web on the development PC defaults to `http://127.0.0.1:8000`. The Android debug manifest permits cleartext HTTP for local development only; production builds must use HTTPS. No backend credentials or API secrets belong in the Flutter app.

Run backend tests from this directory so `app` resolves correctly:

```powershell
python -m pytest -q
```
