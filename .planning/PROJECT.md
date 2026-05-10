# IShare

## What This Is

A macOS native menu bar app that lets users share large files via S3-compatible storage (Cubbit DS3). Files are uploaded with configurable expiration, encrypted on request, and shared via pre-signed URLs. Recipients can be notified through the system mail app with a pre-composed draft.

## Core Value

Users can share any file or directory from Finder in seconds — just right-click, set a duration, and get a link they can forward.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] **CONF-01**: User can configure S3 credentials (endpoint URL, access key, secret key, bucket name)
- [ ] **CONF-02**: App auto-creates the bucket if it doesn't exist
- [ ] **SHAR-01**: User can share files via Finder Quick Actions menu
- [ ] **SHAR-02**: Directories are compressed to a single zip file before upload
- [ ] **SHAR-03**: Single files optionally compress with zip before upload
- [ ] **SHAR-04**: User selects share duration (1h, 1d, 7d, 1m, forever)
- [ ] **SHAR-05**: User can optionally encrypt the file with a password before upload
- [ ] **SHAR-06**: User can optionally enter recipient name, email, and personal message
- [ ] **SHAR-07**: File is uploaded to S3 under a duration-based prefix
- [ ] **SHAR-08**: A pre-signed URL is generated, copied to clipboard
- [ ] **SHAR-09**: S3 lifecycle rules auto-delete files after expiration
- [ ] **SHAR-10**: System mail app opens with pre-composed draft (URL, expiry, sender's message)
- [ ] **TRAY-01**: Menu bar icon shows list of all shared files
- [ ] **TRAY-02**: Each entry shows filename, duration, remaining time, copy-link button, and delete button
- [ ] **TRAY-03**: Shared file list persists across app restarts
- [ ] **DIST-01**: App is distributed as a .dmg

### Out of Scope

- Multi-bucket/endpoint management — v1 targets single Cubbit DS3 configuration
- Client-side encryption beyond password-protected zip — deferred
- In-app email sending — uses system mail client only
- Mobile app — macOS only

## Context

The app serves users (likely teams or professionals) who need to share large files that email can't handle. Cubbit DS3 provides S3-compatible storage, so standard S3 SDK patterns apply. The S3 lifecycle API is used to manage file expiration at the prefix level. Password encryption is handled client-side before upload and communicated out-of-band.

## Constraints

- **Platform**: macOS only — Swift/SwiftUI native app
- **Storage**: S3-compatible (Cubbit DS3) — must support custom endpoint URLs
- **Integration**: Finder Sync Extension for Quick Actions
- **Distribution**: .dmg format
- **Auth**: Static credentials (access key + secret key), not OAuth

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Swift/SwiftUI native app | Full macOS integration for Quick Actions and menu bar | — Pending |
| Lifecycle prefix strategy | S3 lifecycle rules work at prefix level | — Pending |
| Zip default compression | Native macOS support, broadly compatible | — Pending |
| Password encryption out-of-band | Security best practice — password never in email | — Pending |
| System mail for notifications | No SMTP config needed, user controls sending | — Pending |

---
*Last updated: 2026-05-10 after initialization*
