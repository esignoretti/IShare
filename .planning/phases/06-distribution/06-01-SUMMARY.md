---
phase: 06-distribution
plan: 06-01
status: complete
duration: ~5 min
key_files:
  created:
    - build-release.sh
  modified:
    - Sources/IShare/Info.plist
---

# Plan 06-01: Distribution Build Script

## What was built

- **build-release.sh** — Automated release pipeline with these stages:
  - `clean_artifacts()` — Removes previous .app and .dmg
  - `build_release()` — `swift build -c release --arch arm64`
  - `create_app_bundle()` — Constructs `.app` bundle structure with binary + fixed Info.plist
  - `codesign_app()` — Ad-hoc signing with entitlements and runtime hardening
  - `generate_dmg_background()` — Inline Swift script for gradient background (graceful fallback)
  - `create_dmg()` — UDZO compressed HFS+ DMG with size calculation, mount verification
- **Info.plist fix** — `CFBundleExecutable` changed from `$(EXECUTABLE_NAME)` to `IShare` for standalone .app bundle compatibility

## Verification

- `bash build-release.sh` → `IShare.app` with ad-hoc signature, `Mach-O thin arm64` binary, valid Info.plist
- `bash build-release.sh --dmg` → `IShare.dmg` (284K), mounts with `IShare.app` + `Applications` symlink
- No external dependencies — uses only `swift`, `codesign`, `hdiutil`
