# Requirements: IShare

**Defined:** 2026-05-10
**Core Value:** Users can share any file or directory from Finder in seconds

## v1 Requirements

### Configuration

- [x] **CONF-01**: User can enter S3 endpoint URL, access key, secret key, and bucket name in a setup UI
- [x] **CONF-02**: App auto-creates the bucket if it doesn't exist on first run
- [x] **CONF-03**: Configuration persists across app restarts

### Sharing

- [ ] **SHAR-01**: User can trigger share from Finder Quick Actions menu on any file or directory
- [ ] **SHAR-02**: Directories are always compressed to a single zip file before upload
- [ ] **SHAR-03**: Single files optionally compress with zip (user can skip)
- [ ] **SHAR-04**: User selects duration from 1h, 1d, 7d, 1m, or forever
- [ ] **SHAR-05**: User can optionally encrypt the file with a password before upload
- [ ] **SHAR-06**: User can optionally enter recipient name, recipient email, and a personal message
- [ ] **SHAR-07**: File uploads to S3 under prefix `shares/{duration}/{filename}`
- [ ] **SHAR-08**: Pre-signed URL is generated with matching duration and copied to clipboard
- [ ] **SHAR-09**: S3 lifecycle rules auto-delete files after their duration expires
- [ ] **SHAR-10**: System mail app opens with pre-composed draft (recipient, subject, body with URL + expiry + sender's personal message)
- [ ] **SHAR-11**: Encryption password is NOT included in the email body (out-of-band communication)

### Tray

- [ ] **TRAY-01**: Menu bar icon displays list of all shared files
- [ ] **TRAY-02**: Each tray entry shows filename, duration, remaining time, a link-to-copy button, and a delete button
- [ ] **TRAY-03**: Deleting a file from the tray removes it from S3 immediately
- [ ] **TRAY-04**: Shared file list persists across app restarts

### Distribution

- [ ] **DIST-01**: App is distributed as a .dmg file

## v2 Requirements

### Future

- **Multi-bucket support** — Manage multiple S3 endpoints/buckets
- **Upload progress** — Show progress bar in tray menu
- **Drag-and-drop** — Drag files onto menu bar icon to share
- **Custom duration** — User can type a custom expiration time
- **Access notifications** — Get notified when a shared file is downloaded

## Out of Scope

| Feature | Reason |
|---------|--------|
| In-app email sending | SMTP config adds complexity; system mail client is sufficient for v1 |
| Mobile app | macOS only — platform-native experience is the priority |
| Client-side AES encryption beyond zip password | Password-protected zip covers the need; full file encryption deferred |
| OAuth/SSO for app auth | Static credentials are sufficient for a single-bucket v1 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONF-01 | Phase 1 | ✓ Complete |
| CONF-02 | Phase 1 | ✓ Complete |
| CONF-03 | Phase 1 | ✓ Complete |
| SHAR-01 | Phase 2 | ✓ Complete |
| SHAR-02 | Phase 2 | ✓ Complete |
| SHAR-03 | Phase 2 | ✓ Complete |
| SHAR-04 | Phase 2 | ✓ Complete |
| SHAR-05 | Phase 4 | ✓ Complete |
| SHAR-06 | Phase 3 | ✓ Complete |
| SHAR-07 | Phase 2 | ✓ Complete |
| SHAR-08 | Phase 2 | ✓ Complete |
| SHAR-09 | Phase 3 | ✓ Complete |
| SHAR-10 | Phase 4 | ✓ Complete |
| SHAR-11 | Phase 4 | ✓ Complete |
| TRAY-01 | Phase 5 | ✓ Complete |
| TRAY-02 | Phase 5 | ✓ Complete |
| TRAY-03 | Phase 5 | ✓ Complete |
| TRAY-04 | Phase 5 | ✓ Complete |
| DIST-01 | Phase 6 | ✓ Complete |

**Coverage:**
- v1 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-10*
*Last updated: 2026-05-10 after initial definition*
