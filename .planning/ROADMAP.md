# Roadmap: IShare

**6 phases** | **19 requirements** | All v1 requirements covered ✓

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 1 | S3 Credential Configuration | App boots, shows config UI, connects to DS3 | CONF-01, CONF-02, CONF-03 | User can enter credentials and see "Connected" status |
| 2 | Core Share Flow | Upload files with duration, copy pre-signed URL | SHAR-01, SHAR-02, SHAR-03, SHAR-04, SHAR-07, SHAR-08 | Right-click file → set duration → URL on clipboard |
| 3 | Lifecycle & Email Notification | S3 lifecycle rules clean up expired files; system mail notifies recipient | SHAR-06, SHAR-09 | Files auto-delete after expiry; email draft opens with recipient info |
| 4 | Password Encryption | Optional password-based encryption before upload | SHAR-05, SHAR-10, SHAR-11 | Encrypted upload works; email excludes password |
| 5 | Menu Bar Tray | Persistent tray list with copy-link and delete | TRAY-01, TRAY-02, TRAY-03, TRAY-04 | Tray shows shares, copy works, delete removes from S3, survives restart |
| 6 | Distribution | Package as distributable .dmg | DIST-01 | Clean .dmg builds and installs correctly |

---

## Phase Details

### Phase 1: S3 Credential Configuration
**Goal:** App boots, shows config UI, connects to DS3
**Requirements:** CONF-01, CONF-02, CONF-03
**Plans:** 3 plans in 2 waves
**Success Criteria:**
1. On first launch, user sees credential configuration UI (endpoint URL, access key, secret key, bucket name)
2. User can save credentials and they persist across app restarts
3. If bucket doesn't exist, app creates it automatically
4. App shows connection status (Connected / Failed)
5. User can edit/reconfigure credentials from settings

Plans:
- [x] 01-01-PLAN.md — Project scaffold, S3Config model, Keychain + UserDefaults persistence
- [x] 01-02-PLAN.md — S3Service with custom endpoint, connection test, bucket auto-creation
- [x] 01-03-PLAN.md — ConfigView UI, ConnectionStatusView, SettingsView, app lifecycle wiring

### Phase 2: Core Share Flow
**Goal:** Upload files with duration, copy pre-signed URL
**Requirements:** SHAR-01, SHAR-02, SHAR-03, SHAR-04, SHAR-07, SHAR-08
**Plans:** 3 plans in 3 waves
**Success Criteria:**
1. Right-clicking a file in Finder shows "Share with IShare" in Services
2. User is presented with duration picker and optional compression toggle
3. Directories are always compressed to zip before upload
4. Single files respect the "compress?" toggle
5. File uploads to `shares/{duration}/{filename}` on DS3
6. Pre-signed URL is generated and automatically copied to clipboard
7. User sees a success notification after upload

Plans:
- [ ] 02-01-PLAN.md — S3 upload + SigV4 pre-signed URL generation
- [ ] 02-02-PLAN.md — ShareItem model, zip compression, duration picker UI, share sheet
- [ ] 02-03-PLAN.md — Finder Services integration, NSApplicationDelegate, auto-start, cleanup

### Phase 3: Lifecycle & Email Notification
**Goal:** S3 lifecycle rules clean up expired files; system mail notifies recipient
**Requirements:** SHAR-06, SHAR-09
**Plans:** 2 plans in 1 wave
**Success Criteria:**
1. S3 lifecycle rules are configured on the bucket for each duration prefix (1h, 1d, 7d, 1m)
2. Expired files are automatically deleted by S3
3. Share flow includes optional recipient fields (name, email, personal message)
4. When recipient info is provided, system mail app opens with pre-composed draft
5. Draft includes pre-signed URL, expiry date/time, file name, and sender's personal message

Plans:
- [ ] 03-01-PLAN.md — S3 lifecycle rule configuration for all duration prefixes
- [ ] 03-02-PLAN.md — Recipient info model, recipient fields UI, system mail integration

### Phase 4: Password Encryption
**Goal:** Optional password-based encryption before upload
**Requirements:** SHAR-05, SHAR-10, SHAR-11
**Success Criteria:**
1. Share flow includes optional "Encrypt with password" toggle
2. When enabled, user enters a password before upload
3. File is encrypted client-side before being uploaded to DS3
4. Password is NOT included in the email draft or stored locally
5. Tray list shows a lock indicator for encrypted files

### Phase 5: Menu Bar Tray
**Goal:** Persistent tray list with copy-link and delete
**Requirements:** TRAY-01, TRAY-02, TRAY-03, TRAY-04
**Success Criteria:**
1. Menu bar icon shows active shares count as badge
2. Clicking icon shows dropdown list of all shared files
3. Each entry shows: filename, duration, remaining time
4. Each entry has a "Copy Link" button that regenerates pre-signed URL and copies to clipboard
5. Each entry has a "Delete" button that immediately removes the file from S3
6. List persists across app restarts (stored in UserDefaults or local file)
7. Entries for expired files are removed on app launch

### Phase 6: Distribution
**Goal:** Package as distributable .dmg
**Requirements:** DIST-01
**Success Criteria:**
1. App builds as a standalone .app bundle
2. `productbuild` or `create-dmg` produces a .dmg file
3. Dragging .app into Applications folder works correctly
4. All entitlements and code signing are configured
5. DMG includes a nice background and Applications shortcut
