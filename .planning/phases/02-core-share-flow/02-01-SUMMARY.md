---
phase: 02-core-share-flow
plan: 02-01
status: complete
duration: ~3 min
key_files:
  created:
    - Sources/IShare/Extensions/Data+HMAC.swift
  modified:
    - Sources/IShare/Services/S3Service.swift
    - Sources/IShare/Extensions/Data+Hex.swift (deleted)
---

# Plan 02-01: S3 Upload & SigV4 Pre-signed URL

## What was built

- **Data+HMAC.swift** — CommonCrypto-based cryptographic utilities:
  - `Data.hmacSHA256(key:)` and `Data.sha256`
  - `String.sha256Hex`, `String.hmacSHA256`, `String.uriEncoded`
  - `sigV4SigningKey()` — AWS Signing Key derivation
  - `sigV4DateStamp()` and `sigV4AmzDate()` formatters
- **S3Service.uploadFile()** — PUT file to `shares/{duration}/{filename}` with progress callback
- **S3Service.generatePresignedURL()** — SigV4-signed GET URL with `X-Amz-Expires`, `X-Amz-Credential`, `X-Amz-Signature`
- New S3Error cases: `.uploadFailed`, `.presignFailed`, `.signingFailed`

## Deviations

- Removed `Data+Hex.swift` (from Phase 1) — its `hexEncodedString` was superseded by `hexString` in the new HMAC extension
- `String` `withUnsafeBytes` warning suppressed with `_ =` discard assignment

## Verification

- `swift build` passes, 0 warnings
- SigV4 implementation follows AWS standard: canonical request → string-to-sign → HMAC
- Pre-signed URL uses UNSIGNED-PAYLOAD (query param auth, not body signing)
