---
title: Architecture Decisions
date: 2026-05-10
context: Initial exploration session for IShare macOS app
---

# Architecture Decisions

## Technology Stack
- **Language:** Swift/SwiftUI
- **UI:** Menu bar app (AppKit/SwiftUI) + Finder Sync Extension for Quick Actions
- **Distribution:** DMG

## S3 Lifecycle Strategy
- Uploads organized by duration prefix: `shares/1h/`, `shares/1d/`, `shares/7d/`, `shares/1m/`, `shares/forever/`
- Lifecycle rules set at the prefix level on the S3 bucket
- "Forever" files have no lifecycle rule; manual deletion only via tray menu

## Compression
- Default: zip
- Directory uploads always compressed to a single zip file
- User can optionally skip compression for single files

## Encryption
- Password-based encryption applied client-side before upload (e.g., AES-256 with password-derived key)
- Password communicated out-of-band — never included in email or stored locally
- Encrypted files upload alongside a small metadata marker so the app can identify them as password-protected in the tray list

## Email Notification
- Uses system mail (`NSWorkspace.shared.open(URL(string: "mailto:...")!)`) with pre-composed subject and body
- Body includes: pre-signed URL, expiry date/time, sender's personal message, file name
- Email composition is a convenience — sending is manual (user clicks Send in their mail app)

## Share Flow
1. Trigger from Quick Actions or menu bar
2. Select file/directory
3. Set duration (1h/1d/7d/1m/forever)
4. Optionally enable encryption → enter password
5. Optionally enter recipient name, email, personal message
6. Compress (if directory or user chooses)
7. Upload to S3 under duration prefix
8. Generate pre-signed URL → copy to clipboard
9. If recipient info provided → open system mail with pre-composed draft
10. Record share in persistent state (filename, duration, timestamp, recipient, password flag)

## S3 SDK
- Native AWS SDK for Swift (awslabs/aws-sdk-swift)
- Configuration: endpoint URL, access key, secret key, bucket name
- Auto-create bucket if it doesn't exist on first setup
