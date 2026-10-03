# AGENTS.md - water_tank_app

## Build & Verify Commands
- **Static Analysis:** `flutter analyze` (Zero errors / warnings required)
- **Run Tests:** `flutter test` (Note: headless widget tests may fail in Termux without GPU/Vulkan context)
- **Build Release APK:** `flutter build apk --release`

## Architecture & Core Modules
- **Framework:** Flutter (Dart >=3.0.0 <4.0.0) with Provider state management (`ChangeNotifier`).
- **Data Persistence:** Local SQLite database (`sqflite`) via `DatabaseHelper` with transactional integrity for financial operations.
- **Cloud Sync & Auth:** Firebase (`firebase_core`, `cloud_firestore`, `firebase_auth`) with offline-first synchronization logic (`SyncService`).
- **Directory Structure:**
  - `lib/core/`: Database setup, auth services, permission service, connectivity & sync services.
  - `lib/models/`: Domain data models (Client, Supplier, Driver, Tank, Sale, Payment, Expense, Salary, Purchase, etc.).
  - `lib/services/`: Business logic and service layers interacting with SQLite and sync queues.
  - `lib/screens/`: Feature-based UI screens (dashboard, clients, sales, payments, reports, etc.).

## Development Conventions & Gotchas
- **Transactions:** Always execute multi-step financial or inventory updates (e.g., in `SaleService`) within SQLite transactions (`db.transaction(...)`) to avoid partial data corruption.
- **Permissions:** Enforce action-level security using `PermissionService.requirePermission(...)` before executing privileged operations.
- **Async Safety:** Always check `if (!mounted) return;` across async gaps before calling `setState()` or `notifyListeners()`.
