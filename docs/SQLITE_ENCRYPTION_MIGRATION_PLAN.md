# SQLite at-rest encryption migration plan

## Current verified state

- The app opens `AppConstants.localDbName` with the standard `sqflite` `openDatabase` API in `lib/core/database/database_helper.dart`.
- The current open path enables SQLite foreign keys, but does not configure an encryption key or use a SQLCipher-backed database driver.
- Therefore, the app's manual encrypted-backup feature must not be treated as encryption of the live database file.
- The live database contains business and account data. A release change must preserve existing installs and must not silently create an empty replacement database if migration fails.

## Required design before implementation

1. **Select a maintained encryption implementation.** Confirm Flutter/Android compatibility, supported SQLite driver, license, Android ABI support, and maintenance status. Do not add a dependency solely because its API resembles `sqflite`.
2. **Protect the database key.** Generate a cryptographically random key per installation and store it in Android Keystore-backed secure storage. Never hardcode a key, derive it from a username/password, log it, or store it beside the database.
3. **Define upgrade and recovery states.** Distinguish a new installation, an existing plaintext database, an already-encrypted database, a missing key, and a failed/interrupted migration. Unknown/corrupt states must fail closed with a clear recovery message rather than overwrite data.
4. **Preserve user data.** Before conversion, create and verify a recoverable backup using the existing encrypted-backup format. Keep the original database untouched until the encrypted copy has passed integrity and schema checks.
5. **Use an atomic migration protocol.** Build the encrypted database at a temporary path, copy all schema and records using a supported SQLite export/import mechanism, validate row counts and `PRAGMA integrity_check`, close handles, then atomically switch files. Account for `-wal`, `-shm`, and `-journal` sidecars; never copy an open database file without a consistent SQLite backup/snapshot.
6. **Handle crashes safely.** Make every migration phase restartable. Keep a durable migration-state marker, but do not store key material in it. On next launch, detect incomplete work and offer a safe resume/restore path without deleting the only valid copy.
7. **Keep the migration offline-capable.** Existing users must not need Firebase connectivity to open or migrate their local business records. Do not require login-network access as a prerequisite for local data conversion.
8. **Protect temporary material.** Restrict temporary file access, avoid plaintext exports where possible, delete temporary plaintext copies only after successful validation and atomic cutover, and document platform limitations of secure deletion on flash storage.
9. **Add automated tests before enabling by default.** Cover new install, representative legacy schema versions, empty and large databases, Arabic text, financial precision, relationships/foreign keys, migration interruption at each phase, wrong/missing key, insufficient storage, and recovery from backup.
10. **Roll out conservatively.** First ship the migration behind a controlled feature gate to test builds. Do not declare production encryption complete until migration and recovery have passed on representative existing installations and supported Android devices.

## Release acceptance criteria

- [ ] Selected driver and dependency are reviewed and pinned.
- [ ] Key creation, storage, rotation/recovery policy, and failure behavior are documented and tested.
- [ ] Existing plaintext databases migrate without loss, duplicate rows, or schema-version regression.
- [ ] `PRAGMA integrity_check` returns `ok` after conversion and foreign-key checks pass.
- [ ] Simulated process termination at every migration phase never destroys the only valid database.
- [ ] App restart and offline use work after migration.
- [ ] Encrypted backups can restore into the encrypted live-database workflow.
- [ ] Tests prove the live database is not readable as ordinary plaintext SQLite.
- [ ] A documented rollback/recovery process is tested.
- [ ] Real-device migration testing is completed only after automated and code-review gates pass.

## Explicit non-goals

- Do not switch to SQLCipher by changing only the database package name or adding a key to `openDatabase`; the existing database needs a deliberate conversion.
- Do not delete the existing database before the encrypted copy is validated.
- Do not claim encryption-at-rest is complete merely because backups are encrypted or sidecar files are ignored by Git.
