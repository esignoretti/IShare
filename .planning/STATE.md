# State: IShare

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-10)

**Core value:** Users can share any file or directory from Finder in seconds
**Current focus:** Phase 2 — Core Share Flow

## Phase Progress

| Phase | Status | Plans | Progress |
|-------|--------|-------|----------|
| 1 — S3 Credential Configuration | ✓ Complete | 3/3 | 100% |
| 2 — Core Share Flow | ○ Planned | 0/3 | 0% |
| 3 — Lifecycle & Email Notification | ○ Pending | 0/0 | 0% |
| 4 — Password Encryption | ○ Pending | 0/0 | 0% |
| 5 — Menu Bar Tray | ○ Pending | 0/0 | 0% |
| 6 — Distribution | ○ Pending | 0/0 | 0% |

Progress: ██████████ 16%

## Current Phase

**Phase 2: Core Share Flow** — Upload files with duration, copy pre-signed URL

Status: Planned (3 plans, 3 waves)

### Key Decisions for Phase 2

- **SigV4 signing added** via CommonCrypto (system framework, no external deps) for pre-signed URL generation
- **CommonCrypto** used for HMAC-SHA256 — `CCHmac`, `CC_SHA256` — maintains zero-external-dependency approach
- **Zip via /usr/bin/ditto** — standard macOS tool, handles both files and directories
- **macOS Services** for Finder integration (Info.plist NSServices) instead of Finder Sync Extension — simpler, no separate targets
- **Upload path:** `shares/{duration}/{filename}` per SHAR-07
- **Pre-signed URL via SigV4** with X-Amz-Expires matching user-selected duration
- **NotificationCenter** pattern for routing file URLs from AppDelegate to SwiftUI views

## Recent Activity

- 2026-05-10: Phase 2 planned — 3 plans across 3 waves
- 2026-05-10: Phase 1 executed — SPM scaffold, S3Config model, Keychain persistence, ConfigStore, S3Service (URLSession), ConfigView, ConnectionStatusView, SettingsView
- 2026-05-10: Project initialized with requirements and 6-phase roadmap

## Next Action

`/gsd-execute-phase 2` — Execute the Core Share Flow phase
